import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ocr_service.dart';
import '../data/scan_repository.dart';
import '../domain/scan_doc.dart';

final scanRepositoryProvider = Provider<ScanRepository>((ref) => ScanRepository());
final ocrServiceProvider = Provider<OcrService>((ref) => OcrService());

final scansProvider = AsyncNotifierProvider<ScansNotifier, List<ScanDoc>>(ScansNotifier.new);

class ScansNotifier extends AsyncNotifier<List<ScanDoc>> {
  @override
  Future<List<ScanDoc>> build() => ref.read(scanRepositoryProvider).list();

  /// Runs OCR on the captured pages, saves everything and returns the new scan.
  Future<ScanDoc> addScan(List<String> pagePaths) async {
    String text = '';
    try {
      text = await ref.read(ocrServiceProvider).recognize(pagePaths);
    } catch (_) {
      // OCR is best-effort: the scan is still saved.
    }
    final doc = await ref.read(scanRepositoryProvider).create(pagePaths, text);
    state = AsyncData([doc, ...(state.valueOrNull ?? const <ScanDoc>[])]);
    return doc;
  }

  Future<void> remove(ScanDoc doc) async {
    await ref.read(scanRepositoryProvider).delete(doc.id);
    state = AsyncData((state.valueOrNull ?? const <ScanDoc>[]).where((d) => d.id != doc.id).toList());
  }
}
