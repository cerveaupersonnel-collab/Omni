import 'package:flutter/services.dart';

class PdfText {
  const PdfText({required this.text, required this.pages, required this.truncated});
  final String text;
  final int pages;
  final bool truncated;
}

class PdfReadException implements Exception {
  const PdfReadException(this.code);

  /// "encrypted" or "read_failed".
  final String code;
}

/// Extracts the text layer of a PDF natively (PdfBox) on a background thread.
class PdfTextRepository {
  static const MethodChannel _ch = MethodChannel('omni/pdf');

  Future<PdfText> extract(String path, {int maxChars = 280000}) async {
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('extractText', {'path': path, 'maxChars': maxChars});
      return PdfText(
        text: (r?['text'] as String?) ?? '',
        pages: (r?['pages'] as num?)?.toInt() ?? 0,
        truncated: r?['truncated'] == true,
      );
    } on PlatformException catch (e) {
      throw PdfReadException(e.code == 'encrypted' ? 'encrypted' : 'read_failed');
    }
  }
}
