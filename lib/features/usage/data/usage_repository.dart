import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/server/server_client.dart';
import '../../../core/server/server_exceptions.dart';
import '../domain/usage.dart';

class UsageRepository {
  UsageRepository(this._server);
  final ServerClient _server;

  /// Reserves one use on the server. Offline, a local counter applies the same free limit.
  Future<UseTicket> begin(Feature feature) async {
    try {
      final r = await _server.call('beginFeatureUse', {'feature': feature.serverName});
      return UseTicket(
        feature: feature,
        id: r['ticketId'] as String?,
        pro: r['pro'] == true,
        remaining: (r['remaining'] as num?)?.toInt(),
      );
    } on OfflineException {
      return _beginOffline(feature);
    }
  }

  /// success=true keeps the use; success=false (cancelled / failed) gives it back.
  Future<void> finish(UseTicket ticket, {required bool success}) async {
    if (ticket.offline) {
      if (!success) await _refundOffline(ticket.feature);
      return;
    }
    final id = ticket.id;
    if (id == null) return; // Pro: nothing was reserved.
    try {
      await _server.call('finishFeatureUse', {'ticketId': id, 'success': success});
    } catch (_) {
      // Best effort: if this fails the reservation simply stays.
    }
  }

  Future<UsageStatus> status() async {
    final r = await _server.call('getUsageStatus');
    final used = <String, int>{};
    final raw = r['used'];
    if (raw is Map) {
      raw.forEach((key, value) => used[key.toString()] = (value as num).toInt());
    }
    return UsageStatus(
      pro: r['pro'] == true,
      limit: (r['limit'] as num?)?.toInt() ?? kFreeDailyLimit,
      used: used,
    );
  }

  String _key(Feature feature) {
    final day = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    return 'offline_use_${feature.serverName}_$day';
  }

  Future<UseTicket> _beginOffline(Feature feature) async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_key(feature)) ?? 0;
    if (used >= kFreeDailyLimit) throw const DailyLimitException();
    await prefs.setInt(_key(feature), used + 1);
    return UseTicket(feature: feature, pro: false, remaining: kFreeDailyLimit - used - 1, offline: true);
  }

  Future<void> _refundOffline(Feature feature) async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_key(feature)) ?? 0;
    if (used > 0) await prefs.setInt(_key(feature), used - 1);
  }
}
