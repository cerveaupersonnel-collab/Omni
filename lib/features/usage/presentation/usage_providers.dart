import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/server/server_client.dart';
import '../../../core/server/server_exceptions.dart';
import '../data/usage_repository.dart';
import '../domain/usage.dart';

final usageRepositoryProvider =
    Provider<UsageRepository>((ref) => UsageRepository(ref.watch(serverClientProvider)));

/// Today's usage from getUsageStatus. Null when offline.
final usageStatusProvider = FutureProvider.autoDispose<UsageStatus?>((ref) async {
  try {
    return await ref.watch(usageRepositoryProvider).status();
  } on OfflineException {
    return null;
  }
});
