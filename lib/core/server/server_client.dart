import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/integrity_provider.dart';
import '../security/integrity_service.dart';
import 'firebase_access.dart';
import 'server_exceptions.dart';

final serverClientProvider = Provider<ServerClient>((ref) => ServerClient(ref));

/// Single entry point for every Cloud Function call. It signs in, maps errors to
/// typed exceptions and transparently re-runs the Play Integrity check when the
/// server answers "integrity-required".
class ServerClient {
  ServerClient(this._ref);
  final Ref _ref;

  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic>? data]) async {
    try {
      return await _invoke(name, data);
    } on FirebaseAuthException {
      throw const OfflineException();
    } on FirebaseFunctionsException catch (e) {
      if (e.message == 'integrity-required') {
        final status = await _ref.read(integrityProvider.notifier).recheck();
        if (status == IntegrityStatus.blocked) throw const IntegrityBlockedException();
        if (status == IntegrityStatus.trusted) {
          try {
            return await _invoke(name, data);
          } on FirebaseFunctionsException catch (retryError) {
            throw _map(retryError);
          }
        }
        throw const OfflineException();
      }
      throw _map(e);
    }
  }

  Future<Map<String, dynamic>> _invoke(String name, Map<String, dynamic>? data) async {
    await ensureSignedIn();
    final callable = appFunctions.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    final result = await callable.call<dynamic>(data);
    final payload = result.data;
    return payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
  }

  Exception _map(FirebaseFunctionsException e) {
    final message = e.message ?? '';
    switch (e.code) {
      case 'resource-exhausted':
        return const DailyLimitException();
      case 'unavailable':
        return message == 'ai-unavailable' ? const AiUnavailableException() : const OfflineException();
      case 'deadline-exceeded':
        return const OfflineException();
      default:
        return ServerException(e.code, message);
    }
  }
}
