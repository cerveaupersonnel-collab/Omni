import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/ad_ids.dart';

/// Asks for consent (Google UMP) before initialising ads. Nothing is requested
/// from the ad network until the user's choices allow it.
Future<bool> initializeAdsWithConsent() async {
  if (AdIds.banner == null) return false;

  final completer = Completer<bool>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () {
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) async {
        if (!completer.isCompleted) {
          completer.complete(await ConsentInformation.instance.canRequestAds());
        }
      });
    },
    (FormError error) {
      if (!completer.isCompleted) completer.complete(false);
    },
  );

  final canRequest = await completer.future.timeout(const Duration(seconds: 20), onTimeout: () => false);
  if (!canRequest) return false;

  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
  );
  await MobileAds.instance.initialize();
  return true;
}
