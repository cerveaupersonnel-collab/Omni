import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/ad_ids.dart';
import '../../billing/presentation/billing_providers.dart';
import '../data/ads_service.dart';

final adsReadyProvider = FutureProvider<bool>((ref) => initializeAdsWithConsent());

/// Banner for FREE users only. Pro users (confirmed by the server-written
/// entitlement) never see or load ads.
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _failed = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _load() {
    final id = AdIds.banner;
    if (id == null) return;
    final ad = BannerAd(
      adUnitId: id,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
              _failed = true;
            });
          }
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  void _drop() {
    _ad?.dispose();
    _ad = null;
    _loaded = false;
  }

  @override
  Widget build(BuildContext context) {
    final pro = ref.watch(proStatusProvider).valueOrNull;
    final ready = ref.watch(adsReadyProvider).valueOrNull ?? false;
    final show = ready && pro != null && !pro.isPro;

    if (show && _ad == null && !_failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ad == null && !_failed) _load();
      });
    }
    if (!show && _ad != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_drop);
      });
    }

    final ad = _ad;
    if (!show || !_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
