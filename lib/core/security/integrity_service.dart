import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../server/firebase_access.dart';

enum IntegrityStatus {
  /// Server confirmed: genuine app, trusted device, licensed.
  trusted,

  /// Server rejected the app/device (rooted, repackaged, unlicensed).
  blocked,

  /// Could not be verified (offline / transient). Local features keep working,
  /// server-gated features stay locked until verification succeeds.
  unverified,
}

class IntegrityService {
  static const MethodChannel _channel = MethodChannel('omni/integrity');

  /// Honored in debug builds only (kDebugMode is a compile-time constant).
  static const bool _skip = bool.fromEnvironment('OMNI_SKIP_INTEGRITY');

  Future<IntegrityStatus> check() async {
    if (defaultTargetPlatform != TargetPlatform.android) return IntegrityStatus.trusted;
    try {
      return await _run().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      return IntegrityStatus.unverified;
    } on PlatformException catch (e) {
      return e.code == 'transient' ? IntegrityStatus.unverified : _debugBypass(IntegrityStatus.blocked);
    } on FirebaseFunctionsException catch (e) {
      // App Check rejects tampered apps with "unauthenticated".
      return e.code == 'unauthenticated' ? _debugBypass(IntegrityStatus.blocked) : IntegrityStatus.unverified;
    } on FirebaseAuthException {
      return IntegrityStatus.unverified;
    } catch (_) {
      return IntegrityStatus.unverified;
    }
  }

  Future<IntegrityStatus> _run() async {
    await ensureSignedIn();
    final nonceResult = await appFunctions.httpsCallable('getIntegrityNonce').call<dynamic>();
    final nonce = (nonceResult.data as Map)['nonce'] as String;

    final token = await _channel.invokeMethod<String>('requestToken', <String, dynamic>{'nonce': nonce});
    if (token == null || token.isEmpty) return _debugBypass(IntegrityStatus.blocked);

    final verdict = await appFunctions
        .httpsCallable('verifyIntegrity')
        .call<dynamic>(<String, dynamic>{'token': token, 'nonce': nonce});
    final ok = (verdict.data as Map)['ok'] == true;
    return ok ? IntegrityStatus.trusted : _debugBypass(IntegrityStatus.blocked);
  }

  IntegrityStatus _debugBypass(IntegrityStatus status) {
    if (kDebugMode && _skip && status == IntegrityStatus.blocked) return IntegrityStatus.trusted;
    return status;
  }
}
