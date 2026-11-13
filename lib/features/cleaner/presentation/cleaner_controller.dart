import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/media_gateway.dart';
import '../../../core/platform/system_channel.dart';

enum CleanerPhase { idle, scanning, ready, unsupported, permissionDenied, error }

class CleanerState {
  const CleanerState({this.phase = CleanerPhase.idle, this.report, this.storage});
  final CleanerPhase phase;
  final ScanReport? report;
  final DeviceStorage? storage;
}

final cleanerControllerProvider =
    NotifierProvider.autoDispose<CleanerController, CleanerState>(CleanerController.new);

class CleanerController extends AutoDisposeNotifier<CleanerState> {
  @override
  CleanerState build() => const CleanerState();

  MediaGateway get _gateway => ref.read(mediaGatewayProvider);

  Future<bool> hasPermission() => _gateway.hasPermission();

  Future<bool> requestPermission() => _gateway.requestPermission();

  /// The cleaner relies on system delete dialogs, available on Android 11+.
  Future<bool> isSupported() async => (await SystemChannel.storage()).sdk >= 30;

  Future<bool> scan() async {
    state = CleanerState(phase: CleanerPhase.scanning, report: state.report, storage: state.storage);
    try {
      final results = await Future.wait<Object>([SystemChannel.storage(), _gateway.scan()]);
      if (results.length < 2) throw Exception('Unexpected result count from Future.wait');
      state = CleanerState(
        phase: CleanerPhase.ready,
        storage: results[0] as DeviceStorage,
        report: results[1] as ScanReport,
      );
      return true;
    } on MediaPermissionException {
      state = const CleanerState(phase: CleanerPhase.permissionDenied);
      return false;
    } catch (_) {
      state = CleanerState(phase: CleanerPhase.error, report: state.report, storage: state.storage);
      return false;
    }
  }

  Future<bool> delete(List<String> uris) => _gateway.delete(uris);
}
