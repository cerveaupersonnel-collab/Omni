package com.omni.omni

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.min
import kotlin.math.roundToInt

/** Hardware H.264/AAC transcoding with Media3 Transformer (replaces the retired ffmpeg_kit). */
@OptIn(UnstableApi::class)
class VideoChannel(
    private val context: Context,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private var transformer: Transformer? = null
    private var polling: Runnable? = null
    private var pending: MethodChannel.Result? = null

    private class Info(val width: Int, val height: Int, val durationMs: Long, val bitrate: Int, val size: Long)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "probe" -> {
                val path = call.argument<String>("path") ?: return result.error("bad_args", "path", null)
                io.execute {
                    try {
                        val i = probe(path)
                        val map = mapOf(
                            "width" to i.width, "height" to i.height, "durationMs" to i.durationMs,
                            "bitrate" to i.bitrate, "size" to i.size,
                        )
                        main.post { result.success(map) }
                    } catch (e: Exception) {
                        main.post { result.error("probe_failed", e.message, null) }
                    }
                }
            }
            "compress" -> {
                val input = call.argument<String>("input")
                val output = call.argument<String>("output")
                val targetShort = call.argument<Int>("targetShort") ?: 720
                val bitrate = call.argument<Int>("bitrate") ?: 2_000_000
                if (input == null || output == null) {
                    result.error("bad_args", "input/output", null)
                    return
                }
                io.execute {
                    try {
                        val info = probe(input)
                        main.post { start(info, input, output, targetShort, bitrate, result) }
                    } catch (e: Exception) {
                        main.post { result.error("compress_failed", e.message, null) }
                    }
                }
            }
            "cancel" -> {
                stopPolling()
                transformer?.cancel()
                transformer = null
                pending?.error("cancelled", "Compression cancelled", null)
                pending = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun probe(path: String): Info {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            val dur = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val br = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toIntOrNull() ?: 0
            val swap = rot == 90 || rot == 270
            return Info(if (swap) h else w, if (swap) w else h, dur, br, File(path).length())
        } finally {
            r.release()
        }
    }

    private fun start(info: Info, input: String, output: String, targetShort: Int, targetBitrate: Int, result: MethodChannel.Result) {
        File(output).apply { parentFile?.mkdirs(); if (exists()) delete() }

        val short = min(info.width, info.height)
        val videoEffects = ArrayList<Effect>()
        if (short > targetShort && short > 0) {
            val factor = targetShort.toDouble() / short
            var newHeight = (info.height * factor).roundToInt()
            if (newHeight % 2 != 0) newHeight += 1
            videoEffects.add(Presentation.createForHeight(newHeight))
        }
        // Never ask for more bitrate than the source has.
        val bitrate = if (info.bitrate > 0) min(targetBitrate, (info.bitrate * 0.85).toInt()) else targetBitrate

        val encoderFactory = DefaultEncoderFactory.Builder(context)
            .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(bitrate).build())
            .build()

        val t = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoderFactory)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    stopPolling()
                    transformer = null
                    channel.invokeMethod("progress", 100)
                    pending?.success(mapOf("outputPath" to output, "size" to File(output).length()))
                    pending = null
                }

                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                    stopPolling()
                    transformer = null
                    pending?.error("compress_failed", exportException.message, null)
                    pending = null
                }
            })
            .build()

        val edited = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
            .setEffects(Effects(emptyList<AudioProcessor>(), videoEffects))
            .build()

        transformer = t
        pending = result
        t.start(edited, output)
        startPolling(t)
    }

    private fun startPolling(t: Transformer) {
        val holder = ProgressHolder()
        val runnable = object : Runnable {
            override fun run() {
                if (transformer !== t) return
                if (t.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    channel.invokeMethod("progress", holder.progress)
                }
                main.postDelayed(this, 300)
            }
        }
        polling = runnable
        main.post(runnable)
    }

    private fun stopPolling() {
        polling?.let { main.removeCallbacks(it) }
        polling = null
    }
}
