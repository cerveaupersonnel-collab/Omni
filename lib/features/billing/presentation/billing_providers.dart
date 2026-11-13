import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/server/server_client.dart';
import '../../../core/server/server_exceptions.dart';
import '../../usage/presentation/usage_providers.dart';
import '../data/billing_repository.dart';
import '../domain/pro_status.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) => BillingRepository());

final authStateProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

/// Live Pro status. The document users/{uid} is written ONLY by Cloud Functions
/// after Google Play verification; the client just reads it.
final proStatusProvider = StreamProvider<ProStatus>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading) return const Stream<ProStatus>.empty();
  final user = auth.valueOrNull;
  if (user == null) return Stream<ProStatus>.value(ProStatus.free);
  return FirebaseFirestore.instance.doc('users/${user.uid}').snapshots().map((snap) {
    final data = snap.data();
    final expires = (data?['proExpiresAt'] as Timestamp?)?.toDate();
    final isPro = data?['isPro'] == true && expires != null && expires.isAfter(DateTime.now());
    return ProStatus(isPro: isPro, expiresAt: expires);
  });
});

final productsProvider = FutureProvider.autoDispose<List<ProductDetails>>(
  (ref) => ref.watch(billingRepositoryProvider).loadProducts(),
);

class BillingUiState {
  const BillingUiState({this.busy = false, this.message, this.eventId = 0});
  final bool busy;
  final String? message;
  final int eventId;
}

final billingControllerProvider =
    NotifierProvider<BillingController, BillingUiState>(BillingController.new);

class BillingController extends Notifier<BillingUiState> {
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Timer? _restoreTimer;
  int _eventId = 0;

  @override
  BillingUiState build() {
    _sub = ref.read(billingRepositoryProvider).purchases.listen(
          _onPurchases,
          onError: (Object _) => _emit('Billing is unavailable right now.'),
        );
    ref.onDispose(() {
      _sub?.cancel();
      _restoreTimer?.cancel();
    });
    return const BillingUiState();
  }

  void _emit(String message) {
    _eventId++;
    state = BillingUiState(busy: false, message: message, eventId: _eventId);
  }

  void _setBusy(bool busy) {
    state = BillingUiState(busy: busy, eventId: _eventId);
  }

  Future<void> buy(ProductDetails product) async {
    _setBusy(true);
    try {
      final r = await ref.read(serverClientProvider).call('getBillingAccountId');
      final started = await ref.read(billingRepositoryProvider).buy(product, r['accountId'] as String);
      if (!started) _emit('Could not start the purchase. Please try again.');
    } on OfflineException {
      _emit('No internet connection.');
    } on IntegrityBlockedException {
      _setBusy(false);
    } catch (_) {
      _emit('Could not start the purchase. Please try again.');
    }
  }

  Future<void> restore() async {
    _setBusy(true);
    try {
      final r = await ref.read(serverClientProvider).call('getBillingAccountId');
      await ref.read(billingRepositoryProvider).restore(r['accountId'] as String);
      // Google Play sends nothing when there is nothing to restore.
      _restoreTimer?.cancel();
      _restoreTimer = Timer(const Duration(seconds: 8), () {
        if (state.busy) _emit('No purchases found to restore.');
      });
    } on OfflineException {
      _emit('No internet connection.');
    } on IntegrityBlockedException {
      _setBusy(false);
    } catch (_) {
      _emit('Could not restore purchases. Please try again.');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    _restoreTimer?.cancel();
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _setBusy(true);
        case PurchaseStatus.error:
          await _finish(purchase);
          _emit(purchase.error?.message ?? 'Purchase failed. Please try again.');
        case PurchaseStatus.canceled:
          await _finish(purchase);
          _emit('Purchase canceled.');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(purchase);
      }
    }
  }

  Future<void> _finish(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await ref.read(billingRepositoryProvider).complete(purchase);
    } catch (_) {}
  }

  /// Server-side verification: the entitlement is granted by the server only.
  Future<void> _verify(PurchaseDetails purchase) async {
    if (!BillingRepository.productIds.contains(purchase.productID)) {
      await _finish(purchase);
      return;
    }
    try {
      final r = await ref.read(serverClientProvider).call('verifyPurchase', {
        'purchaseToken': purchase.verificationData.serverVerificationData,
      });
      await _finish(purchase);
      ref.invalidate(usageStatusProvider);
      _emit(r['isPro'] == true ? 'Welcome to OMNI Pro!' : 'This subscription is not active.');
    } on OfflineException {
      // Not completed on purpose: Play redelivers it on the next launch.
      _emit("No connection. We'll activate Pro as soon as you're back online.");
    } on IntegrityBlockedException {
      _setBusy(false);
    } on ServerException catch (e) {
      if (e.message == 'purchase-belongs-to-another-account') {
        _emit('This purchase belongs to a different OMNI account.');
      } else {
        _emit('We could not verify your purchase. Please try Restore Purchase.');
      }
    } catch (_) {
      _emit('We could not verify your purchase. Please try Restore Purchase.');
    }
  }
}
