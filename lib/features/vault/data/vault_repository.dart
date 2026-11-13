import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/platform/media_gateway.dart';
import '../domain/vault_item.dart';

/// Files live in the app's private storage: other apps and the gallery cannot see them.
class VaultRepository {
  VaultRepository(this._gateway);
  final MediaGateway _gateway;

  Future<Directory> dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/vault');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _indexFile() async => File('${(await dir()).path}/index.json');

  Future<List<VaultItem>> list() async {
    final f = await _indexFile();
    if (!await f.exists()) return [];
    try {
      final raw = jsonDecode(await f.readAsString()) as List;
      final d = await dir();
      final items = raw
          .map((e) => VaultItem.fromJson(e as Map<String, dynamic>))
          .where((i) => File('${d.path}/${i.fileName}').existsSync())
          .toList();
      items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<VaultItem> items) async {
    final f = await _indexFile();
    await f.writeAsString(jsonEncode(items.map((i) => i.toJson()).toList()), flush: true);
  }

  String _extension(MediaItem m) {
    final dot = m.name.lastIndexOf('.');
    if (dot > 0 && dot < m.name.length - 1) return m.name.substring(dot + 1).toLowerCase();
    return m.isVideo ? 'mp4' : 'jpg';
  }

  /// Copies a gallery item into the vault. The caller then asks the system to delete the original.
  Future<VaultItem> add(MediaItem media) async {
    final d = await dir();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final fileName = '$id.${_extension(media)}';
    final size = await _gateway.copyToVault(media.uri, '${d.path}/$fileName');
    final item = VaultItem(
      id: id,
      fileName: fileName,
      displayName: media.name.isEmpty ? fileName : media.name,
      isVideo: media.isVideo,
      size: size,
      addedAt: DateTime.now(),
    );
    final items = await list();
    await _write([item, ...items]);
    return item;
  }

  /// Puts the file back in the gallery (Pictures/OMNI or Movies/OMNI) and removes it from the vault.
  Future<void> restore(VaultItem item) async {
    final d = await dir();
    await _gateway.saveToGallery('${d.path}/${item.fileName}', item.displayName, video: item.isVideo);
    await deletePermanently(item);
  }

  Future<void> deletePermanently(VaultItem item) async {
    final d = await dir();
    final f = File('${d.path}/${item.fileName}');
    if (await f.exists()) await f.delete();
    final items = await list();
    await _write(items.where((i) => i.id != item.id).toList());
  }
}

final vaultRepositoryProvider = Provider<VaultRepository>((ref) => VaultRepository(ref.watch(mediaGatewayProvider)));
