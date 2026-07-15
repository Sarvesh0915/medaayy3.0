import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'supabase_service.dart';

/// Product IDs — these must match exactly what you create in
/// Play Console → Monetize → Products → Subscriptions.
/// Each product has two base plans (monthly/yearly) inside it, per the
/// setup described in the "how to get Play Billing" conversation.
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

  /// Never throws — a personal test APK almost certainly has no real Play
  /// Console products set up yet, and this must not be able to block app
  /// startup if Play Billing isn't available or misbehaves on this device.
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

  /// Returns the store's real price string (e.g. "₹99.00") if available,
  /// otherwise null — screens should fall back to the hardcoded price only
  /// as a display placeholder before Play Console products are approved.
  /// Finds the right monthly/yearly offer within a subscription product and
  /// starts the purchase flow. Completes when Play Billing reports success,
  /// failure, or the user cancels.
  Future<PurchaseResult> buy(String productId, String billingCycle) async {
    final product = _products[productId];
    if (product == null) {
      return PurchaseResult.failure('Product not found — check it exists and is active in Play Console.');
    }

    String? offerToken;
    PurchaseParam param;

    if (product is GooglePlayProductDetails) {
      try {
        final offers = product.productDetails.subscriptionOfferDetails;
        final offer = offers?.firstWhere(
          (o) => o.basePlanId == billingCycle,
          orElse: () => offers!.first,
        );
        
        offerToken = offer?.pricingPhases.isNotEmpty == true 
            ? offer!.pricingPhases.first.offerToken 
            : null;
      } catch (_) {}

      param = GooglePlayPurchaseParam(
        productDetails: product,
        changeSubscriptionParam: offerToken != null 
            ? ChangeSubscriptionParam(oldPurchaseDetails: null, prorationMode: null) // standard layout for version
            : null,
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

    final completer = Completer<PurchaseResult>();
    _pendingCompleters[productId] = completer;

    final param = GooglePlayPurchaseParam(
  productDetails: ...,
  offerToken: offerToken, // Delete or comment out this line
)

    try {
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _pendingCompleters.remove(productId);
      return PurchaseResult.failure(e.toString());
    }

    return completer.future;
  }

  final Map<String, Completer<PurchaseResult>> _pendingCompleters = {};

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
        // IMPORTANT: verify server-side BEFORE trusting this purchase.
        // A purchase reported here is what the device says happened — your
        // backend must confirm it against the Android Publisher API using
        // the service account you linked in Play Console, via the
        // verify-purchase Edge Function (see supabase/functions/verify-purchase).
        final verified = await SupabaseService.instance.verifyPurchase(
          productId: purchase.productID,
          purchaseToken: purchase.verificationData.serverVerificationData,
        );

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
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
