import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/media_gateway.dart';
import '../../../core/platform/system_channel.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/media_thumb.dart';

/// In-app gallery picker (returns the chosen items so the originals can be removed afterwards).
class MediaPickerScreen extends ConsumerStatefulWidget {
  const MediaPickerScreen({super.key});

  @override
  ConsumerState<MediaPickerScreen> createState() => _MediaPickerScreenState();
}

class _MediaPickerScreenState extends ConsumerState<MediaPickerScreen> {
  List<MediaItem>? _items;
  final Set<String> _selected = {};
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final gateway = ref.read(mediaGatewayProvider);
    if (!await gateway.hasPermission()) {
      if (!mounted) return;
      final agree = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Allow access to photos and videos?'),
          content: const Text(
            'OMNI needs to read your gallery so you can choose what to hide in your Vault. '
            'Nothing is uploaded or shared.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continue')),
          ],
        ),
      );
      if (agree != true || !await gateway.requestPermission()) {
        if (mounted) setState(() => _denied = true);
        return;
      }
    }
    try {
      final items = await gateway.list();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _denied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose items to hide'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, items!.where((i) => _selected.contains(i.uri)).toList()),
            child: Text('Done (${_selected.length})'),
          ),
        ],
      ),
      body: SafeArea(
        child: _denied
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Access to photos and videos is needed.', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: SystemChannel.openAppSettings, child: const Text('Open Settings')),
                    ],
                  ),
                ),
              )
            : items == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.violet))
                : items.isEmpty
                    ? const Center(child: Text('No photos or videos found.'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final selected = _selected.contains(item.uri);
                          return GestureDetector(
                            onTap: () => setState(() => selected ? _selected.remove(item.uri) : _selected.add(item.uri)),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                MediaThumb(item: item),
                                if (selected)
                                  Container(decoration: BoxDecoration(color: AppColors.violet.withOpacity(0.45), borderRadius: BorderRadius.circular(16))),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? AppColors.lime : Colors.white70),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
