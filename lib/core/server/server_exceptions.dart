/// The free daily limit for a feature is used up.
class DailyLimitException implements Exception {
  const DailyLimitException();
}

/// No network or the server could not be reached.
class OfflineException implements Exception {
  const OfflineException();
}

/// The AI provider failed on the server side.
class AiUnavailableException implements Exception {
  const AiUnavailableException();
}

/// Play Integrity failed: the app must show the blocking screen.
class IntegrityBlockedException implements Exception {
  const IntegrityBlockedException();
}

/// Any other server error. [message] is the machine-readable server message.
class ServerException implements Exception {
  const ServerException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'ServerException($code, $message)';
}
