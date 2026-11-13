package com.omni.omni

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.concurrent.Callable
import java.util.concurrent.Executors

/**
 * Play-compliant media access: MediaStore + system delete dialogs (scoped storage).
 * No MANAGE_EXTERNAL_STORAGE. Deleting always goes through MediaStore.createDeleteRequest,
 * so the user approves every deletion in a system dialog.
 */
class MediaChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val REQ_DELETE = 7001
        const val REQ_PERMISSION = 7002
        private const val MAX_ANALYZED = 4000
        private const val BLUR_THRESHOLD = 30.0
        private const val LARGE_VIDEO_BYTES = 50L * 1024 * 1024
        private const val RELATIVE_PATH = "relative_path"
    }

    private val ioPool = Executors.newFixedThreadPool(2)
    private val analysisPool = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())
    private var pendingDelete: MethodChannel.Result? = null
    private var pendingPermission: MethodChannel.Result? = null

    private class Row(
        val uri: Uri, val name: String, val size: Long, val width: Int, val height: Int,
        val duration: Long, val path: String, val video: Boolean,
    ) {
        @Volatile var sharp = -1.0
        @Volatile var hash = 0L
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasPermission())
            "requestPermission" -> requestPermission(result)
            "list" -> background(result) { list(call.argument<Int>("limit") ?: 500) }
            "scan" -> background(result) { scan() }
            "thumbnail" -> background(result) {
                thumbnail(call.argument<String>("uri")!!, call.argument<Int>("size") ?: 256, call.argument<Boolean>("video") == true)
            }
            "delete" -> delete(call.argument<List<String>>("uris") ?: emptyList(), result)
            "copyToVault" -> background(result) { copyToVault(call.argument<String>("uri")!!, call.argument<String>("dest")!!) }
            "saveToGallery" -> background(result) {
                saveToGallery(call.argument<String>("path")!!, call.argument<String>("name")!!, call.argument<Boolean>("video") == true)
            }
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, block: () -> Any?) {
        ioPool.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: SecurityException) {
                main.post { result.error("permission", e.message, null) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.message, null) }
            }
        }
    }

    // ---- permissions ----
    private fun permissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= 33) {
            arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO)
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

    private fun hasPermission(): Boolean =
        permissions().all { ContextCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED }

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(activity, permissions(), REQ_PERMISSION)
    }

    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != REQ_PERMISSION) return false
        pendingPermission?.success(hasPermission())
        pendingPermission = null
        return true
    }

    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQ_DELETE) return false
        pendingDelete?.success(resultCode == Activity.RESULT_OK)
        pendingDelete = null
        return true
    }

    // ---- queries ----
    private fun query(video: Boolean, limit: Int): List<Row> {
        if (!hasPermission()) throw SecurityException("Media permission missing")
        val collection = if (video) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val pathColumn = if (Build.VERSION.SDK_INT >= 29) RELATIVE_PATH else MediaStore.MediaColumns.DISPLAY_NAME
        val projection = arrayOf(
            MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.WIDTH, MediaStore.MediaColumns.HEIGHT, pathColumn,
            if (video) MediaStore.Video.Media.DURATION else MediaStore.MediaColumns.DATE_ADDED,
        )
        val rows = ArrayList<Row>()
        activity.contentResolver.query(collection, projection, null, null, "${MediaStore.MediaColumns.DATE_ADDED} DESC")?.use { c ->
            while (c.moveToNext() && rows.size < limit) {
                rows.add(
                    Row(
                        ContentUris.withAppendedId(collection, c.getLong(0)),
                        c.getString(1) ?: "", c.getLong(2), c.getInt(3), c.getInt(4),
                        if (video) c.getLong(6) else 0L, c.getString(5) ?: "", video,
                    ),
                )
            }
        }
        return rows
    }

    private fun item(r: Row): Map<String, Any?> = mapOf(
        "uri" to r.uri.toString(), "name" to r.name, "size" to r.size, "width" to r.width,
        "height" to r.height, "duration" to r.duration, "sharpness" to r.sharp, "video" to r.video,
    )

    private fun list(limit: Int): List<Map<String, Any?>> {
        val rows = (query(false, limit) + query(true, limit)).sortedByDescending { it.uri.lastPathSegment?.toLongOrNull() ?: 0L }
        return rows.take(limit).map { item(it) }
    }

    private fun scan(): Map<String, Any?> {
        val images = query(false, 20_000)
        val videos = query(true, 5_000)
        val analyzed = images.take(MAX_ANALYZED)
        analysisPool.invokeAll(analyzed.map { r -> Callable { analyze(r) } })

        val valid = analyzed.filter { it.sharp >= 1.0 } // flat images would all hash alike
        val parent = IntArray(valid.size) { it }
        fun find(x: Int): Int {
            var a = x
            while (parent[a] != a) {
                parent[a] = parent[parent[a]]
                a = parent[a]
            }
            return a
        }
        for (i in valid.indices) {
            for (j in i + 1 until valid.size) {
                if (java.lang.Long.bitCount(valid[i].hash xor valid[j].hash) <= 3 && similarAspect(valid[i], valid[j])) {
                    parent[find(i)] = find(j)
                }
            }
        }
        val duplicateGroups = valid.indices.groupBy { find(it) }.values.filter { it.size > 1 }.map { group ->
            group.map { valid[it] }
                .sortedWith(compareByDescending<Row> { it.width.toLong() * it.height }.thenByDescending { it.size })
                .map { item(it) }
        }

        val blurry = analyzed.filter { it.sharp in 0.0..BLUR_THRESHOLD }.sortedBy { it.sharp }.take(300).map { item(it) }
        val large = videos.filter { it.size >= LARGE_VIDEO_BYTES }.sortedByDescending { it.size }.take(100).map { item(it) }
        val whatsapp = (images + videos).filter { isWhatsAppReceived(it) }.sortedByDescending { it.size }.take(2_000).map { item(it) }

        return mapOf(
            "duplicates" to duplicateGroups,
            "blurry" to blurry,
            "largeVideos" to large,
            "whatsapp" to whatsapp,
            "imageCount" to images.size,
            "videoCount" to videos.size,
            "imageBytes" to images.sumOf { it.size },
            "videoBytes" to videos.sumOf { it.size },
        )
    }

    private fun isWhatsAppReceived(r: Row): Boolean {
        val p = r.path.lowercase()
        return p.contains("whatsapp") && !p.contains("/sent") && !p.contains("private")
    }

    private fun similarAspect(a: Row, b: Row): Boolean {
        if (a.height == 0 || b.height == 0) return false
        val ra = a.width.toDouble() / a.height
        val rb = b.width.toDouble() / b.height
        return Math.abs(ra - rb) / ra < 0.02
    }

    private fun lum(p: Int): Double = 0.299 * ((p shr 16) and 0xFF) + 0.587 * ((p shr 8) and 0xFF) + 0.114 * (p and 0xFF)

    private fun analyze(r: Row) {
        val bmp = decode(r.uri, 128) ?: return
        val g = Bitmap.createScaledBitmap(bmp, 128, 128, true)
        val px = IntArray(128 * 128)
        g.getPixels(px, 0, 128, 0, 0, 128, 128)
        val gray = DoubleArray(px.size) { lum(px[it]) }
        var sum = 0.0
        var sumSq = 0.0
        var n = 0
        for (y in 1 until 127) {
            for (x in 1 until 127) {
                val i = y * 128 + x
                val l = -4 * gray[i] + gray[i - 1] + gray[i + 1] + gray[i - 128] + gray[i + 128]
                sum += l
                sumSq += l * l
                n++
            }
        }
        val mean = sum / n
        r.sharp = sumSq / n - mean * mean

        val small = Bitmap.createScaledBitmap(bmp, 9, 8, true)
        val hp = IntArray(72)
        small.getPixels(hp, 0, 9, 0, 0, 9, 8)
        var h = 0L
        for (y in 0 until 8) {
            for (x in 0 until 8) {
                h = (h shl 1) or (if (lum(hp[y * 9 + x]) > lum(hp[y * 9 + x + 1])) 1L else 0L)
            }
        }
        r.hash = h
        small.recycle()
        if (g !== bmp) g.recycle()
        bmp.recycle()
    }

    private fun decode(uri: Uri, target: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        activity.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= target && bounds.outHeight / (sample * 2) >= target) sample *= 2
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        return activity.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
    }

    private fun thumbnail(uri: String, size: Int, video: Boolean): ByteArray? {
        val u = Uri.parse(uri)
        val bmp: Bitmap? = if (Build.VERSION.SDK_INT >= 29) {
            try {
                activity.contentResolver.loadThumbnail(u, Size(size, size), null)
            } catch (e: Exception) {
                null
            }
        } else if (!video) decode(u, size) else null
        val bitmap = bmp ?: return null
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
        return out.toByteArray()
    }

    // ---- delete / vault / gallery ----
    private fun delete(uris: List<String>, result: MethodChannel.Result) {
        if (uris.isEmpty()) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT < 30) {
            result.error("unsupported", "Android 11 or newer is required", null)
            return
        }
        try {
            val pi = MediaStore.createDeleteRequest(activity.contentResolver, uris.map { Uri.parse(it) })
            pendingDelete = result
            activity.startIntentSenderForResult(pi.intentSender, REQ_DELETE, null, 0, 0, 0)
        } catch (e: Exception) {
            pendingDelete = null
            result.error("failed", e.message, null)
        }
    }

    private fun copyToVault(uri: String, dest: String): Long {
        val file = File(dest)
        file.parentFile?.mkdirs()
        val input = activity.contentResolver.openInputStream(Uri.parse(uri)) ?: throw IOException("Cannot open source")
        input.use { src -> file.outputStream().use { src.copyTo(it) } }
        return file.length()
    }

    private fun saveToGallery(path: String, name: String, video: Boolean): String {
        if (Build.VERSION.SDK_INT < 29) throw UnsupportedOperationException("Android 10 or newer is required")
        val resolver = activity.contentResolver
        val collection = if (video) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val ext = name.substringAfterLast('.', "").lowercase()
        val mime = android.webkit.MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: if (video) "video/mp4" else "image/jpeg"
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(RELATIVE_PATH, if (video) "Movies/OMNI" else "Pictures/OMNI")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(collection, values) ?: throw IOException("Cannot create media entry")
        resolver.openOutputStream(uri)?.use { out -> File(path).inputStream().use { it.copyTo(out) } }
            ?: throw IOException("Cannot write media")
        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return uri.toString()
    }
}
