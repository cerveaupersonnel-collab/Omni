import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/scan_doc.dart';

/// Scans live in the app's private storage (offline-first, not visible in the gallery).
class ScanRepository {
  Future<Directory> _root() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/scans');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<ScanDoc>> list() async {
    final root = await _root();
    final docs = <ScanDoc>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final meta = File('${entity.path}/meta.json');
      if (!await meta.exists()) continue;
      try {
        final json = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
        final pages = (json['pages'] as List).map((p) => '${entity.path}/$p').where((p) => File(p).existsSync()).toList();
        if (pages.isEmpty) continue;
        final segments = entity.uri.pathSegments.where((s) => s.isNotEmpty).toList();
        final id = segments.isEmpty ? entity.uri.pathSegments.last : segments.last;
        docs.add(ScanDoc(
          id: id,
          createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
          pagePaths: pages,
          text: json['text'] as String? ?? '',
        ));
      } catch (_) {
        // Skip unreadable entries.
      }
    }
    docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  Future<ScanDoc> create(List<String> tempPaths, String text) async {
    final root = await _root();
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    final dir = await Directory('${root.path}/$id').create(recursive: true);
    final names = <String>[];
    for (var i = 0; i < tempPaths.length; i++) {
      final name = 'page_${i + 1}.jpg';
      await File(tempPaths[i]).copy('${dir.path}/$name');
      names.add(name);
    }
    await File('${dir.path}/meta.json').writeAsString(
      jsonEncode({'createdAt': now.millisecondsSinceEpoch, 'pages': names, 'text': text}),
    );
    return ScanDoc(
      id: id,
      createdAt: now,
      pagePaths: names.map((n) => '${dir.path}/$n').toList(),
      text: text,
    );
  }

  Future<void> delete(String id) async {
    final root = await _root();
    final dir = Directory('${root.path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Builds an A4 PDF (one scan page per PDF page) in the temp directory.
  Future<String> exportPdf(ScanDoc doc) async {
    final pdf = pw.Document();
    for (final path in doc.pagePaths) {
      final image = pw.MemoryImage(await File(path).readAsBytes());
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }
    final tmp = await getTemporaryDirectory();
    final out = File('${tmp.path}/omni_scan_${doc.id}.pdf');
    await out.writeAsBytes(await pdf.save());
    return out.path;
  }
}
