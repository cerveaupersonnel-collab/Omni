import 'package:flutter_test/flutter_test.dart';
import 'package:omni/core/platform/media_gateway.dart';
import 'package:omni/features/home/domain/home_card_id.dart';
import 'package:omni/features/scan/domain/scan_doc.dart';
import 'package:omni/features/usage/domain/usage.dart';
import 'package:omni/features/vault/domain/vault_item.dart';

MediaItem _item(String uri, int size) => MediaItem(
      uri: uri,
      name: '$uri.jpg',
      size: size,
      width: 100,
      height: 100,
      durationMs: 0,
      sharpness: 100,
      isVideo: false,
    );

void main() {
  test('free daily limit is 3 and feature names match the server', () {
    expect(kFreeDailyLimit, 3);
    expect(Feature.values.map((f) => f.serverName), ['scan', 'cleaner', 'compressor', 'vault']);
  });

  test('home cards are unique and include chat_pdf', () {
    final layout = HomeLayout.initial();
    expect(layout.order.length, 5);
    expect(layout.order.toSet().length, 5);
    expect(layout.order.map((c) => c.serverName), contains('chat_pdf'));
    expect(layout.hidden, isEmpty);
  });

  test('ScanDoc title is formatted from its date', () {
    final doc = ScanDoc(id: '1', createdAt: DateTime(2026, 11, 5, 9, 7), pagePaths: const ['a.jpg'], text: '');
    expect(doc.title, 'Scan 2026-11-05 09:07');
  });

  test('VaultItem survives a JSON round trip', () {
    final item = VaultItem(
      id: '42',
      fileName: '42.jpg',
      displayName: 'holiday.jpg',
      isVideo: false,
      size: 1234,
      addedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
    final copy = VaultItem.fromJson(item.toJson());
    expect(copy.id, item.id);
    expect(copy.fileName, item.fileName);
    expect(copy.displayName, item.displayName);
    expect(copy.size, item.size);
    expect(copy.addedAt, item.addedAt);
  });

  test('ScanReport keeps the best copy of each duplicate group', () {
    final report = ScanReport(
      duplicateGroups: [
        [_item('a', 1000), _item('b', 800), _item('c', 700)],
        [_item('d', 500), _item('e', 400)],
      ],
      blurry: [_item('f', 100)],
      largeVideos: const [],
      whatsapp: const [],
      imageCount: 6,
      videoCount: 0,
      imageBytes: 3500,
      videoBytes: 0,
    );
    expect(report.duplicateCount, 3);
    expect(report.duplicateBytes, 800 + 700 + 400);
    expect(report.blurryBytes, 100);
  });

  test('MediaItem parses the native map', () {
    final item = MediaItem.fromMap({
      'uri': 'content://media/external/images/media/7',
      'name': 'x.jpg',
      'size': 2048,
      'width': 4000,
      'height': 3000,
      'duration': 0,
      'sharpness': 55.5,
      'video': false,
    });
    expect(item.size, 2048);
    expect(item.sharpness, 55.5);
    expect(item.isVideo, isFalse);
  });
}
