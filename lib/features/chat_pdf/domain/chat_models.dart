enum ChatAction {
  ask('ask'),
  summarize('summarize'),
  translate('translate'),
  findTables('find_tables');

  const ChatAction(this.serverName);
  final String serverName;
}

class ChatTurn {
  const ChatTurn({required this.role, required this.content});

  /// "user" or "assistant".
  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class ChatAnswer {
  const ChatAnswer({required this.text, required this.pro, required this.remaining});
  final String text;
  final bool pro;
  final int? remaining;
}
