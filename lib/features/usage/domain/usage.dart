/// Features whose work runs on-device and are gated by beginFeatureUse / finishFeatureUse.
enum Feature {
  scan,
  cleaner,
  compressor,
  vault;

  String get serverName => name;
}

const int kFreeDailyLimit = 3;

/// A free use reserved before an operation. Pro users get a ticket without an id.
class UseTicket {
  const UseTicket({required this.feature, required this.pro, required this.remaining, this.id, this.offline = false});
  final Feature feature;
  final String? id;
  final bool pro;
  final int? remaining;
  final bool offline;
}

class UsageStatus {
  const UsageStatus({required this.pro, required this.limit, required this.used});
  final bool pro;
  final int limit;
  final Map<String, int> used;
}
