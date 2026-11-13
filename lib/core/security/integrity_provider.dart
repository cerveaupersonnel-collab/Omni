import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'integrity_service.dart';

final integrityServiceProvider = Provider<IntegrityService>((ref) => IntegrityService());

class IntegrityNotifier extends AsyncNotifier<IntegrityStatus> {
  @override
  Future<IntegrityStatus> build() => ref.read(integrityServiceProvider).check();

  /// Re-runs the check and publishes the result (blocked flips the whole app).
  Future<IntegrityStatus> recheck() async {
    final status = await ref.read(integrityServiceProvider).check();
    state = AsyncData(status);
    return status;
  }
}

final integrityProvider =
    AsyncNotifierProvider<IntegrityNotifier, IntegrityStatus>(IntegrityNotifier.new);
