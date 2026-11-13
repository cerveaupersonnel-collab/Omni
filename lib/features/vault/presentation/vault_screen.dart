import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/media_gateway.dart';
import '../../../core/platform/system_channel.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../home/domain/home_card_id.dart';
import '../../usage/domain/usage.dart';
import '../../usage/presentation/use_feature.dart';
import '../data/vault_auth.dart';
import '../data/vault_repository.dart';
import '../domain/vault_item.dart';
import 'media_picker_screen.dart';
import 'vault_viewer.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _authenticating = false;
  bool _suppressLock = false;
  bool _working = false;
  String? _message;
  String _dirPath = '';
  List<VaultItem> _items = const [];
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChannel.setSecure(true); // no screenshots, hidden in recents
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChannel.setSecure(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_suppressLock && !_authenticating && _unlocked) {
      // Lock when the app goes to the background; close any open viewer.
      final route = _route;
      if (route != null && mounted) Navigator.of(context).popUntil((r) => r == route);
      setState(() => _unlocked = false);
    } else if (state == AppLifecycleState.resumed && !_unlocked && !_authenticating && !_suppressLock) {
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !mounted) return;
    _authenticating = true;
    final result = await ref.read(vaultAuthProvider).authenticate();
    _authenticating = false;
    if (!mounted) return;
    switch (result) {
      case VaultAuthResult.success:
        setState(() {
          _unlocked = true;
          _message = null;
        });
        await _reload();
      case VaultAuthResult.unsupported:
        setState(() => _message = 'Set up a screen lock or fingerprint/face unlock in your phone settings to use the Vault.');
      case VaultAuthResult.failed:
        setState(() => _message = 'Authentication failed.');
    }
  }

  Future<void> _reload() async {
    final repo = ref.read(vaultRepositoryProvider);
    final items = await repo.list();
    final dir = await repo.dir();
    if (mounted) setState(() {
      _items = items;
      _dirPath = dir.path;
    });
  }

  void _toast(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _add() async {
    final picked = await Navigator.of(context).push<List<MediaItem>>(
      MaterialPageRoute<List<MediaItem>>(builder: (_) => const MediaPickerScreen()),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final session = await beginFeature(context, ref, Feature.vault);
    if (session == null) return;

    _suppressLock = true;
    setState(() => _working = true);
    final repo = ref.read(vaultRepositoryProvider);
    final copied = <MediaItem>[];
    try {
      for (final media in picked) {
        try {
          await repo.add(media);
          copied.add(media);
        } catch (_) {
          // Skip files that cannot be read.
        }
      }
      await session.finish(success: copied.isNotEmpty);
      var originalsRemoved = false;
      if (copied.isNotEmpty) {
        try {
          // Android shows a system dialog; the originals leave the gallery only if you approve.
          originalsRemoved = await ref.read(mediaGatewayProvider).delete(copied.map((m) => m.uri).toList());
        } on MediaUnsupportedException {
          originalsRemoved = false;
        }
      }
      await _reload();
      _toast(copied.isEmpty
          ? 'Could not add the selected files.'
          : originalsRemoved
              ? '${copied.length} item(s) hidden in your Vault.'
              : '${copied.length} item(s) added. The originals are still in your gallery: delete them to fully hide the files.');
    } finally {
      await session.finish(success: false); // no-op if already finished
      _suppressLock = false;
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _itemMenu(VaultItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.output_rounded),
              title: const Text('Remove from Vault'),
              subtitle: const Text('Restore to your gallery'),
              onTap: () => Navigator.pop(c, 'restore'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              title: const Text('Delete permanently'),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    final repo = ref.read(vaultRepositoryProvider);
    try {
      if (action == 'restore') {
        await repo.restore(item);
        _toast('Restored to Pictures/OMNI or Movies/OMNI.');
      } else {
        if (!mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Delete permanently?'),
            content: const Text('This file will be erased and cannot be recovered.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
            ],
          ),
        );
        if (ok != true) return;
        await repo.deletePermanently(item);
      }
      await _reload();
    } on MediaUnsupportedException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('That did not work. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FeatureScaffold(
      card: HomeCardId.vault,
      floatingActionButton: _unlocked
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.violet,
              foregroundColor: AppColors.white,
              onPressed: _working ? null : _add,
              icon: _working
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_rounded),
              label: Text(_working ? 'Hiding…' : 'Add'),
            )
          : null,
      body: !_unlocked
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 72, color: AppColors.violet),
                    const SizedBox(height: 16),
                    Text('Vault is locked', style: theme.textTheme.titleLarge),
                    if (_message != null) ...[
                      const SizedBox(height: 8),
                      Text(_message!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.lime)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Unlock'),
                    ),
                  ],
                ),
              ),
            )
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Nothing hidden yet. Tap Add to move photos and videos out of your gallery into this private space.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => VaultViewer(items: _items, initialIndex: i, dirPath: _dirPath)),
                      ),
                      onLongPress: () => _itemMenu(item),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: item.isVideo
                            ? Container(
                                color: Colors.white10,
                                child: const Center(child: Icon(Icons.play_circle_fill_rounded, size: 40, color: Colors.white70)),
                              )
                            : Image.file(File('$_dirPath/${item.fileName}'), fit: BoxFit.cover, cacheWidth: 300),
                      ),
                    );
                  },
                ),
    );
  }
}
