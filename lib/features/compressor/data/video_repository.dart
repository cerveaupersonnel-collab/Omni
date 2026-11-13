import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/compressor_models.dart';

class CompressionCancelled implements Exception {
  const CompressionCancelled();
}

class CompressionFailed implements Exception {
  const CompressionFailed();
}

/// Hardware transcoding through the native Media3 Transformer bridge.
class VideoRepository {
  VideoRepository() {
    _ch.setMethodCallHandler(_onCall);
  }

  static const MethodChannel _ch = MethodChannel('omni/video');
  final StreamController<int> _progress = StreamController<int>.broadcast();

  Stream<int> get progress => _progress.stream;

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'progress') _progress.add((call.arguments as num).toInt());
    return null;
  }

  Future<VideoInfo> probe(String path) async {
    final r = await _ch.invokeMapMethod<String, dynamic>('probe', {'path': path});
    return VideoInfo(
      width: (r?['width'] as num?)?.toInt() ?? 0,
      height: (r?['height'] as num?)?.toInt() ?? 0,
      durationMs: (r?['durationMs'] as num?)?.toInt() ?? 0,
      bitrate: (r?['bitrate'] as num?)?.toInt() ?? 0,
      size: (r?['size'] as num?)?.toInt() ?? 0,
    );
  }

  Future<CompressionResult> compress({required String input, required String output, required VideoPreset preset}) async {
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('compress', {
        'input': input,
        'output': output,
        'targetShort': preset.targetShortSide,
        'bitrate': preset.bitrate,
      });
      return CompressionResult(outputPath: r?['outputPath'] as String? ?? output, size: (r?['size'] as num?)?.toInt() ?? 0);
    } on PlatformException catch (e) {
      throw e.code == 'cancelled' ? const CompressionCancelled() : const CompressionFailed();
    }
  }

  Future<void> cancel() => _ch.invokeMethod<void>('cancel');

  void dispose() => _progress.close();
}

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  final repo = VideoRepository();
  ref.onDispose(repo.dispose);
  return repo;
});
