package com.omni.omni

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SystemChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "storageStats" -> {
                val stat = StatFs(Environment.getDataDirectory().path)
                result.success(
                    mapOf(
                        "total" to stat.totalBytes,
                        "free" to stat.availableBytes,
                        "sdk" to Build.VERSION.SDK_INT,
                    ),
                )
            }
            "setSecure" -> {
                if (call.argument<Boolean>("enabled") == true) {
                    activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
            "openAppSettings" -> {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + activity.packageName))
                activity.startActivity(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
