import 'package:flutter/foundation.dart';

/// Production ad unit ids come from --dart-define=ADMOB_BANNER_ID=ca-app-pub-xxx/yyy.
/// Debug builds always use Google's official test banner. Release builds with no
/// id configured show no ads (they never ship test ids).
class AdIds {
  AdIds._();

  static const String _banner = String.fromEnvironment('ADMOB_BANNER_ID');
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';

  static String? get banner => kDebugMode ? _testBanner : (_banner.isEmpty ? null : _banner);
}
