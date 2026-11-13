import 'package:flutter/services.dart';

class DeviceStorage {
  const DeviceStorage({required this.total, required this.free, required this.sdk});
  final int total;
  final int free;
  final int sdk;
  int get used => total - free;
}

class SystemChannel {
  static const MethodChannel _ch = MethodChannel('omni/system');

  static Future<DeviceStorage> storage() async {
    final r = await _ch.invokeMapMethod<String, dynamic>('storageStats');
    return DeviceStorage(
      total: (r?['total'] as num?)?.toInt() ?? 0,
      free: (r?['free'] as num?)?.toInt() ?? 0,
      sdk: (r?['sdk'] as num?)?.toInt() ?? 0,
    );
  }

  /// Blocks screenshots and hides the app in the recents list (used by the Vault).
  static Future<void> setSecure(bool enabled) => _ch.invokeMethod<void>('setSecure', {'enabled': enabled});

  static Future<void> openAppSettings() => _ch.invokeMethod<void>('openAppSettings');
}
