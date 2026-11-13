import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../data/video_repository.dart';
import '../domain/compressor_models.dart';

enum CompressPhase { idle, probing, ready, compressing, done }

class CompressorState {
  const CompressorState({
    this.phase = CompressPhase.idle,
    this.inputPath,
    this.info,
    this.preset = VideoPreset.whatsappStatus,
    this.progress = 0,
    this.result,
    this.message,
  });

  final CompressPhase phase;
  final String? inputPath;
  final VideoInfo? info;
  final VideoPreset preset;
  final int progress;
  final CompressionResult? result;
  final String? message;

  CompressorState copyWith({
    CompressPhase? phase,
    String? inputPath,
    VideoInfo? info,
    VideoPreset? preset,
    int? progress,
    CompressionResult? result,
    String? message,
    bool clearResult = false,
    bool clearMessage = false,
  }) {
    return CompressorState(
      phase: phase ?? this.phase,
      inputPath: inputPath ?? this.inputPath,
      info: info ?? this.info,
      preset: preset ?? this.preset,
      progress: progress ?? this.progress,
      result: clearResult ? null : (result ?? this.result),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

final compressorControllerProvider =
    NotifierProvider.autoDispose<CompressorController, CompressorState>(CompressorController.new);

class CompressorController extends AutoDisposeNotifier<CompressorState> {
  @override
  CompressorState build() => const CompressorState();

  VideoRepository get _repo => ref.read(videoRepositoryProvider);

  Future<void> pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    state = state.copyWith(phase: CompressPhase.probing, clearResult: true, clearMessage: true);
    try {
      final info = await _repo.probe(picked.path);
      state = state.copyWith(phase: CompressPhase.ready, inputPath: picked.path, info: info, progress: 0);
    } catch (_) {
      state = state.copyWith(phase: state.inputPath == null ? CompressPhase.idle : CompressPhase.ready, message: 'Could not read this video.');
    }
  }

  void setPreset(VideoPreset preset) => state = state.copyWith(preset: preset);

  Future<bool> compress() async {
    final input = state.inputPath;
    if (input == null || state.phase == CompressPhase.compressing) return false;
    state = state.copyWith(phase: CompressPhase.compressing, progress: 0, clearResult: true, clearMessage: true);

    final tmp = await getTemporaryDirectory();
    final output = '${tmp.path}/omni_compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final sub = _repo.progress.listen((p) => state = state.copyWith(progress: p.clamp(0, 100)));
    try {
      final result = await _repo.compress(input: input, output: output, preset: state.preset);
      state = state.copyWith(phase: CompressPhase.done, result: result, progress: 100);
      return true;
    } on CompressionCancelled {
      state = state.copyWith(phase: CompressPhase.ready, message: 'Compression cancelled.');
    } catch (_) {
      state = state.copyWith(phase: CompressPhase.ready, message: 'Compression failed. Try another preset or video.');
    } finally {
      await sub.cancel();
    }
    return false;
  }

  Future<void> cancel() => _repo.cancel();
}
