import '../../../core/server/server_client.dart';
import '../domain/chat_models.dart';

/// Thin client for the chatWithPDF Cloud Function (the OpenAI key never leaves the server).
/// May throw DailyLimitException, AiUnavailableException, OfflineException,
/// IntegrityBlockedException, or ServerException (message "document-too-long").
class ChatPdfRepository {
  ChatPdfRepository(this._server);
  final ServerClient _server;

  Future<ChatAnswer> ask({
    required String pdfText,
    ChatAction action = ChatAction.ask,
    String question = '',
    String targetLanguage = 'English',
    List<ChatTurn> history = const [],
  }) async {
    final r = await _server.call('chatWithPDF', {
      'pdfText': pdfText,
      'action': action.serverName,
      'question': question,
      'targetLanguage': targetLanguage,
      'history': history.map((t) => t.toJson()).toList(),
    });
    return ChatAnswer(
      text: r['answer'] as String? ?? '',
      pro: r['pro'] == true,
      remaining: (r['remaining'] as num?)?.toInt(),
    );
  }
}
