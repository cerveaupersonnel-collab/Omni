import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MediaPermissionException implements Exception {
  const MediaPermissionException();
}

class MediaUnsupportedException implements Exception {
  const MediaUnsupportedException(this.message);
  final String message;
}

class MediaItem {
  const MediaItem({
    required this.uri,
    required this.name,
    required this.size,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.sharpness,
    required this.isVideo,
  });

  factory MediaItem.fromMap(Map<Object?, Object?> m) => MediaItem(
        uri: m['uri'] as String,
        name: m['name'] as String? ?? '',
        size: (m['size'] as num?)?.toInt() ?? 0,
        width: (m['width'] as num?)?.toInt() ?? 0,
        height: (m['height'] as num?)?.toInt() ?? 0,
        durationMs: (m['duration'] as num?)?.toInt() ?? 0,
        sharpness: (m['sharpness'] as num?)?.toDouble() ?? -1,
        isVideo: m['video'] == true,
      );

  final String uri;
  final String name;
  final int size;
  final int width;
  final int height;
  final int durationMs;
  final double sharpness;
  final bool isVideo;
}

class ScanReport {
  const ScanReport({
    required this.duplicateGroups,
    required this.blurry,
    required this.largeVideos,
    required this.whatsapp,
    required this.imageCount,
    required this.videoCount,
    required this.imageBytes,
    required this.videoBytes,
  });

  /// Each group is sorted best-first: index 0 is the copy to keep.
  final List<List<MediaItem>> duplicateGroups;
  final List<MediaItem> blurry;
  final List<MediaItem> largeVideos;
  final List<MediaItem> whatsapp;
  final int imageCount;
  final int videoCount;
  final int imageBytes;
  final int videoBytes;

  int get duplicateBytes => duplicateGroups.fold(0, (a, g) => a + g.skip(1).fold(0, (b, i) => b + i.size));
  int get duplicateCount => duplicateGroups.fold(0, (a, g) => a + g.length - 1);
  int get blurryBytes => blurry.fold(0, (a, i) => a + i.size);
  int get largeVideoBytes => largeVideos.fold(0, (a, i) => a + i.size);
  int get whatsappBytes => whatsapp.fold(0, (a, i) => a + i.size);
}

/// Dart side of the native MediaStore bridge (Play-compliant scoped storage access).
class MediaGateway {
  static const MethodChannel _ch = MethodChannel('omni/media');
  final LinkedHashMap<String, Uint8List> _thumbs = LinkedHashMap();

  Future<bool> hasPermission() async => (await _ch.invokeMethod<bool>('hasPermission')) ?? false;

  Future<bool> requestPermission() async => (await _ch.invokeMethod<bool>('requestPermission')) ?? false;

  Future<List<MediaItem>> list({int limit = 600}) async {
    final raw = await _guard(() => _ch.invokeListMethod<dynamic>('list', {'limit': limit}));
    return (raw ?? const []).map((e) => MediaItem.fromMap(e as Map<Object?, Object?>)).toList();
  }

  Future<ScanReport> scan() async {
    final r = await _guard(() => _ch.invokeMapMethod<String, dynamic>('scan'));
    List<MediaItem> items(dynamic v) =>
        ((v as List?) ?? const []).map((e) => MediaItem.fromMap(e as Map<Object?, Object?>)).toList();
    return ScanReport(
      duplicateGroups: ((r?['duplicates'] as List?) ?? const []).map(items).toList(),
      blurry: items(r?['blurry']),
      largeVideos: items(r?['largeVideos']),
      whatsapp: items(r?['whatsapp']),
      imageCount: (r?['imageCount'] as num?)?.toInt() ?? 0,
      videoCount: (r?['videoCount'] as num?)?.toInt() ?? 0,
      imageBytes: (r?['imageBytes'] as num?)?.toInt() ?? 0,
      videoBytes: (r?['videoBytes'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Uint8List?> thumbnail(MediaItem item, {int size = 256}) async {
    final cached = _thumbs.remove(item.uri);
    if (cached != null) {
      _thumbs[item.uri] = cached;
      return cached;
    }
    try {
      final bytes = await _ch.invokeMethod<Uint8List>('thumbnail', {'uri': item.uri, 'size': size, 'video': item.isVideo});
      if (bytes != null) {
        _thumbs[item.uri] = bytes;
        if (_thumbs.length > 300) _thumbs.remove(_thumbs.keys.first);
      }
      return bytes;
    } on PlatformException {
      return null;
    }
  }

  /// Opens the system delete dialog. Returns true only if the user approved.
  Future<bool> delete(List<String> uris) async {
    try {
      return (await _ch.invokeMethod<bool>('delete', {'uris': uris})) ?? false;
    } on PlatformException catch (e) {
      if (e.code == 'unsupported') throw MediaUnsupportedException(e.message ?? 'Unsupported');
      rethrow;
    }
  }

  Future<int> copyToVault(String uri, String dest) async =>
      (await _ch.invokeMethod<num>('copyToVault', {'uri': uri, 'dest': dest}))?.toInt() ?? 0;

  Future<void> saveToGallery(String path, String name, {required bool video}) async {
    try {
      await _ch.invokeMethod<String>('saveToGallery', {'path': path, 'name': name, 'video': video});
    } on PlatformException catch (e) {
      throw MediaUnsupportedException(e.message ?? 'Could not save to gallery');
    }
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      if (e.code == 'permission') throw const MediaPermissionException();
      rethrow;
    }
  }
}

final mediaGatewayProvider = Provider<MediaGateway>((ref) => MediaGateway());
