import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'supabase_service.dart';

/// Product IDs — these must match exactly what you create in
/// Play Console → Monetize → Products → Subscriptions.
class BillingProductIds {
  static const alarm = 'alarm_plan';
  static const call = 'call_plan';
}

class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Map<String, ProductDetails> _products = {};
  final Map<String, Completer<PurchaseResult>> _pendingCompleters = {};

  /// Initializes the billing service and queries available products.
  Future<bool> init() async {
    try {
      final available = await _iap.isAvailable();
      if (!available) return false;

      final response = await _iap.queryProductDetails({BillingProductIds.alarm, BillingProductIds.call});
      _products = {for (final p in response.productDetails) p.id: p};

      _sub = _iap.purchaseStream.listen(_onPurchaseUpdate, onError: (_) {});
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _sub?.cancel();

  /// Returns the store's real price string (e.g. "₹99.00") if available.
  String? priceFor(String productId) => _products[productId]?.price;

  /// Starts the purchase flow for a product.
  Future<PurchaseResult> buy(String productId, String billingCycle) async {
    final product = _products[productId];
    if (product == null) {
      return PurchaseResult.failure('Product not found — check it exists and is active in Play Console.');
    }

    PurchaseParam param;
    if (product is GooglePlayProductDetails) {
      param = GooglePlayPurchaseParam(
        productDetails: product,
        changeSubscriptionParam: null,
      );
    } else {
      param = PurchaseParam(productDetails: product);
    }

    final completer = Completer<PurchaseResult>();
    _pendingCompleters[productId] = completer;

    try {
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _pendingCompleters.remove(productId);
      return PurchaseResult.failure(e.toString());
    }

    return completer.future;
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final completer = _pendingCompleters.remove(purchase.productID);

      if (purchase.status == PurchaseStatus.pending) {
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        completer?.complete(PurchaseResult.failure(purchase.error?.message ?? 'Purchase failed'));
      } else if (purchase.status == PurchaseStatus.canceled) {
        completer?.complete(PurchaseResult.failure('Cancelled'));
      } else if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        final verified = await SupabaseService.instance.verifyPurchase(
          productId: purchase.productID,
          purchaseToken: purchase.verificationData.serverVerificationData,
        );

        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }

        completer?.complete(
          verified ? PurchaseResult.success() : PurchaseResult.failure('Could not verify purchase'),
        );
      }
    }
  }
}

class PurchaseResult {
  final bool success;
  final String? error;
  PurchaseResult.success() : success = true, error = null;
  PurchaseResult.failure(this.error) : success = false;
}