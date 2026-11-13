import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR (Google ML Kit). Nothing is uploaded.
class OcrService {
  Future<String> recognize(List<String> imagePaths) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final parts = <String>[];
      for (final path in imagePaths) {
        final result = await recognizer.processImage(InputImage.fromFilePath(path));
        if (result.text.trim().isNotEmpty) parts.add(result.text.trim());
      }
      return parts.join('\n\n');
    } finally {
      await recognizer.close();
    }
  }
}
