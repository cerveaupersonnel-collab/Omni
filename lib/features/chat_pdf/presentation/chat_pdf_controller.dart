import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/server/server_exceptions.dart';
import '../data/pdf_text_repository.dart';
import '../domain/chat_models.dart';
import 'chat_pdf_providers.dart';

const int kMaxPdfBytes = 50 * 1024 * 1024;

class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text, this.isError = false});
  final bool fromUser;
  final String text;
  final bool isError;
}

enum ChatOutcome { ok, limitReached, failed }

class ChatPdfState {
  const ChatPdfState({
    this.fileName,
    this.pdfText,
    this.pages = 0,
    this.truncated = false,
    this.messages = const [],
    this.loadingPdf = false,
    this.sending = false,
    this.notice,
    this.remaining,
  });

  final String? fileName;
  final String? pdfText;
  final int pages;
  final bool truncated;
  final List<ChatMessage> messages;
  final bool loadingPdf;
  final bool sending;
  final String? notice;
  final int? remaining;

  bool get hasPdf => pdfText != null;

  ChatPdfState copyWith({
    String? fileName,
    String? pdfText,
    int? pages,
    bool? truncated,
    List<ChatMessage>? messages,
    bool? loadingPdf,
    bool? sending,
    String? notice,
    bool clearNotice = false,
    int? remaining,
  }) {
    return ChatPdfState(
      fileName: fileName ?? this.fileName,
      pdfText: pdfText ?? this.pdfText,
      pages: pages ?? this.pages,
      truncated: truncated ?? this.truncated,
      messages: messages ?? this.messages,
      loadingPdf: loadingPdf ?? this.loadingPdf,
      sending: sending ?? this.sending,
      notice: clearNotice ? null : (notice ?? this.notice),
      remaining: remaining ?? this.remaining,
    );
  }
}

final chatPdfControllerProvider =
    NotifierProvider.autoDispose<ChatPdfController, ChatPdfState>(ChatPdfController.new);

class ChatPdfController extends AutoDisposeNotifier<ChatPdfState> {
  @override
  ChatPdfState build() => const ChatPdfState();

  Future<void> pickPdf() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final path = file.path;
    if (path == null) return;
    if (file.size > kMaxPdfBytes) {
      state = state.copyWith(notice: 'This PDF is larger than 50 MB. Please choose a smaller file.');
      return;
    }

    state = state.copyWith(loadingPdf: true, clearNotice: true);
    try {
      final pdf = await ref.read(pdfTextRepositoryProvider).extract(path);
      if (pdf.text.trim().isEmpty) {
        state = state.copyWith(
          loadingPdf: false,
          notice: 'No selectable text found. If this is a scanned PDF, use Omni Scan to recognize its text first.',
        );
        return;
      }
      state = ChatPdfState(
        fileName: file.name,
        pdfText: pdf.text,
        pages: pdf.pages,
        truncated: pdf.truncated,
        notice: pdf.truncated ? 'Long document: only the first part of the text is used.' : null,
      );
    } on PdfReadException catch (e) {
      state = state.copyWith(
        loadingPdf: false,
        notice: e.code == 'encrypted'
            ? 'This PDF is password protected.'
            : 'Could not read this PDF. Try another file.',
      );
    }
  }

  void clear() => state = const ChatPdfState();

  Future<ChatOutcome> ask(String question) {
    return _send(ChatAction.ask, label: question, question: question);
  }

  Future<ChatOutcome> summarize() => _send(ChatAction.summarize, label: 'Summarize this document');

  Future<ChatOutcome> findTables() => _send(ChatAction.findTables, label: 'Find all tables');

  Future<ChatOutcome> translate(String language) =>
      _send(ChatAction.translate, label: 'Translate to $language', language: language);

  Future<ChatOutcome> _send(ChatAction action, {required String label, String question = '', String language = 'English'}) async {
    final text = state.pdfText;
    if (text == null || state.sending) return ChatOutcome.failed;

    final history = state.messages
        .where((m) => !m.isError)
        .toList()
        .reversed
        .take(10)
        .toList()
        .reversed
        .map((m) => ChatTurn(role: m.fromUser ? 'user' : 'assistant', content: m.text))
        .toList();

    state = state.copyWith(
      messages: [...state.messages, ChatMessage(fromUser: true, text: label)],
      sending: true,
      clearNotice: true,
    );

    try {
      final answer = await ref.read(chatPdfRepositoryProvider).ask(
            pdfText: text,
            action: action,
            question: question,
            targetLanguage: language,
            history: history,
          );
      state = state.copyWith(
        messages: [...state.messages, ChatMessage(fromUser: false, text: answer.text)],
        sending: false,
        remaining: answer.remaining,
      );
      return ChatOutcome.ok;
    } on DailyLimitException {
      state = state.copyWith(sending: false, notice: 'Daily free limit reached.');
      return ChatOutcome.limitReached;
    } on OfflineException {
      return _fail('AI features need an internet connection.');
    } on AiUnavailableException {
      return _fail('The AI service is busy right now. Please try again in a moment.');
    } on IntegrityBlockedException {
      state = state.copyWith(sending: false);
      return ChatOutcome.failed;
    } on ServerException catch (e) {
      return _fail(e.message == 'document-too-long' ? 'This document is too long to analyze.' : 'Something went wrong. Please try again.');
    } catch (_) {
      return _fail('Something went wrong. Please try again.');
    }
  }

  ChatOutcome _fail(String message) {
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(fromUser: false, text: message, isError: true)],
      sending: false,
    );
    return ChatOutcome.failed;
  }
}
