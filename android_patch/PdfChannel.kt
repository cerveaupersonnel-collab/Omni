package com.omni.omni

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Extracts text from a PDF on a background thread (PdfBox keeps large files on disk, not in RAM). */
class PdfChannel(context: Context) : MethodChannel.MethodCallHandler {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        PDFBoxResourceLoader.init(context.applicationContext)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "extractText") {
            result.notImplemented()
            return
        }
        val path = call.argument<String>("path")
        val maxChars = call.argument<Int>("maxChars") ?: 280_000
        if (path.isNullOrEmpty()) {
            result.error("bad_args", "path is required", null)
            return
        }
        executor.execute {
            try {
                PDDocument.load(File(path), MemoryUsageSetting.setupTempFileOnly()).use { doc ->
                    if (doc.isEncrypted) {
                        main.post { result.error("encrypted", "PDF is password protected", null) }
                        return@execute
                    }
                    val pages = doc.numberOfPages
                    val stripper = PDFTextStripper()
                    val out = StringBuilder()
                    var truncated = false
                    for (page in 1..pages) {
                        stripper.startPage = page
                        stripper.endPage = page
                        out.append(stripper.getText(doc)).append('\n')
                        if (out.length >= maxChars) {
                            truncated = page < pages || out.length > maxChars
                            out.setLength(maxChars)
                            break
                        }
                    }
                    val payload = mapOf("text" to out.toString(), "pages" to pages, "truncated" to truncated)
                    main.post { result.success(payload) }
                }
            } catch (e: Exception) {
                main.post { result.error("read_failed", e.message, null) }
            }
        }
    }
}
