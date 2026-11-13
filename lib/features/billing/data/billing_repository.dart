import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

class BillingUnavailableException implements Exception {
  const BillingUnavailableException();
}

class BillingRepository {
  static const String monthlyId = 'omni_pro_monthly';
  static const String yearlyId = 'omni_pro_yearly';
  static const Set<String> productIds = {monthlyId, yearlyId};

  final InAppPurchase _iap = InAppPurchase.instance;

  Stream<List<PurchaseDetails>> get purchases => _iap.purchaseStream;

  Future<List<ProductDetails>> loadProducts() async {
    if (!await _iap.isAvailable()) throw const BillingUnavailableException();
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null || response.productDetails.isEmpty) {
      throw const BillingUnavailableException();
    }
    final list = [...response.productDetails];
    list.sort((a, b) => (a.id == monthlyId ? 0 : 1).compareTo(b.id == monthlyId ? 0 : 1));
    return list;
  }

  /// [accountId] binds the purchase to this user (obfuscated account id); the
  /// server rejects tokens that do not match.
  Future<bool> buy(ProductDetails product, String accountId) {
    return _iap.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(productDetails: product, applicationUserName: accountId),
    );
  }

  Future<void> restore(String accountId) => _iap.restorePurchases(applicationUserName: accountId);

  Future<void> complete(PurchaseDetails purchase) => _iap.completePurchase(purchase);
}
