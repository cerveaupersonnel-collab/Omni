package com.omni.omni

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var media: MediaChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "omni/integrity").setMethodCallHandler(IntegrityChannel(applicationContext))
        MethodChannel(messenger, "omni/pdf").setMethodCallHandler(PdfChannel(applicationContext))
        MethodChannel(messenger, "omni/system").setMethodCallHandler(SystemChannel(this))

        val videoChannel = MethodChannel(messenger, "omni/video")
        videoChannel.setMethodCallHandler(VideoChannel(applicationContext, videoChannel))

        val mediaChannel = MediaChannel(this)
        MethodChannel(messenger, "omni/media").setMethodCallHandler(mediaChannel)
        media = mediaChannel
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (media?.onActivityResult(requestCode, resultCode) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (media?.onPermissionResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
