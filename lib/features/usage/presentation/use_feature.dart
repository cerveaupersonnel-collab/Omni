import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/server/server_exceptions.dart';
import '../../billing/presentation/paywall_screen.dart';
import '../domain/usage.dart';
import 'usage_providers.dart';

/// A reserved free use. Call [finish] exactly when the operation ends:
/// success keeps the use, cancel or failure gives it back. Safe to call twice.
class FeatureSession {
  FeatureSession._(this._container, this._ticket);

  final ProviderContainer _container;
  final UseTicket _ticket;
  bool _done = false;

  Future<void> finish({required bool success}) async {
    if (_done) return;
    _done = true;
    await _container.read(usageRepositoryProvider).finish(_ticket, success: success);
    _container.invalidate(usageStatusProvider);
  }
}

/// Call before an operation in Scan / Clean / Compress / Vault. Returns null when the
/// operation must not start (free limit reached: the paywall is shown).
Future<FeatureSession?> beginFeature(BuildContext context, WidgetRef ref, Feature feature) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final container = ProviderScope.containerOf(context);
  try {
    final ticket = await ref.read(usageRepositoryProvider).begin(feature);
    container.invalidate(usageStatusProvider);
    return FeatureSession._(container, ticket);
  } on DailyLimitException {
    messenger.showSnackBar(
      const SnackBar(content: Text('Daily free limit reached. Upgrade to OMNI Pro for unlimited use.')),
    );
    await navigator.push(PaywallScreen.route());
    return null;
  } on IntegrityBlockedException {
    return null; // IntegrityGate is already showing the blocking screen.
  } on ServerException {
    messenger.showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
    return null;
  }
}
