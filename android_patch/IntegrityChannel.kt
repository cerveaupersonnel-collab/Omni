package com.omni.omni

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityServiceException
import com.google.android.play.core.integrity.IntegrityTokenRequest
import com.google.android.play.core.integrity.model.IntegrityErrorCode
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class IntegrityChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "requestToken") {
            result.notImplemented()
            return
        }
        val nonce = call.argument<String>("nonce")
        if (nonce.isNullOrEmpty()) {
            result.error("bad_args", "nonce is required", null)
            return
        }
        IntegrityManagerFactory.create(context)
            .requestIntegrityToken(IntegrityTokenRequest.builder().setNonce(nonce).build())
            .addOnSuccessListener { response -> result.success(response.token()) }
            .addOnFailureListener { e ->
                val code = (e as? IntegrityServiceException)?.errorCode
                val transient = code == IntegrityErrorCode.NETWORK_ERROR ||
                    code == IntegrityErrorCode.GOOGLE_SERVER_UNAVAILABLE ||
                    code == IntegrityErrorCode.CLIENT_TRANSIENT_ERROR ||
                    code == IntegrityErrorCode.TOO_MANY_REQUESTS ||
                    code == IntegrityErrorCode.CANNOT_BIND_TO_SERVICE ||
                    code == IntegrityErrorCode.INTERNAL_ERROR
                result.error(if (transient) "transient" else "integrity_error", e.message, null)
            }
    }
}
