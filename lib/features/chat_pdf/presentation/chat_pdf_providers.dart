import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/server/server_client.dart';
import '../data/chat_pdf_repository.dart';
import '../data/pdf_text_repository.dart';

final chatPdfRepositoryProvider =
    Provider<ChatPdfRepository>((ref) => ChatPdfRepository(ref.watch(serverClientProvider)));

final pdfTextRepositoryProvider = Provider<PdfTextRepository>((ref) => PdfTextRepository());
