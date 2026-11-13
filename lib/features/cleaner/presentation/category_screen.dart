import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/media_gateway.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/media_thumb.dart';
import 'cleaner_controller.dart';

enum CleanCategory {
  duplicates('Duplicate photos'),
  blurry('Blurry photos'),
  largeVideos('Large videos'),
  whatsapp('WhatsApp media');

  const CleanCategory(this.title);
  final String title;
}

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key, required this.category});
  final CleanCategory category;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final Set<String> _selected = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final report = ref.read(cleanerControllerProvider).report;
    // Safe defaults: only duplicate extras are preselected (the best copy is kept).
    if (report != null && widget.category == CleanCategory.duplicates) {
      for (final g in report.duplicateGroups) {
        _selected.addAll(g.skip(1).map((i) => i.uri));
      }
    }
  }

  List<MediaItem> _items(ScanReport r) {
    switch (widget.category) {
      case CleanCategory.duplicates:
        return r.duplicateGroups.expand((g) => g).toList();
      case CleanCategory.blurry:
        return r.blurry;
      case CleanCategory.largeVideos:
        return r.largeVideos;
      case CleanCategory.whatsapp:
        return r.whatsapp;
    }
  }

  Future<void> _delete(ScanReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(cleanerControllerProvider.notifier);
    final items = _items(report).where((i) => _selected.contains(i.uri)).toList();
    if (items.isEmpty) return;
    final bytes = items.fold<int>(0, (a, i) => a + i.size);

    setState(() => _busy = true);
    try {
      final deleted = await controller.delete(items.map((i) => i.uri).toList());
      if (deleted) {
        messenger.showSnackBar(SnackBar(content: Text('Freed ${formatBytes(bytes)}')));
        _selected.clear();
        await controller.scan();
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Nothing was deleted.')));
      }
    } on MediaUnsupportedException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not delete the selected files.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(MediaItem item) {
    setState(() => _selected.contains(item.uri) ? _selected.remove(item.uri) : _selected.add(item.uri));
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(cleanerControllerProvider).report;
    final theme = Theme.of(context);
    if (report == null) return Scaffold(appBar: AppBar(title: Text(widget.category.title)));

    final all = _items(report);
    _selected.removeWhere((u) => !all.any((i) => i.uri == u));
    final selectedBytes = all.where((i) => _selected.contains(i.uri)).fold<int>(0, (a, i) => a + i.size);

    Widget tile(MediaItem item, {bool keep = false}) {
      final selected = _selected.contains(item.uri);
      return GestureDetector(
        onTap: () => _toggle(item),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MediaThumb(item: item),
            if (selected) Container(decoration: BoxDecoration(color: AppColors.violet.withOpacity(0.45), borderRadius: BorderRadius.circular(16))),
            Positioned(
              top: 6,
              right: 6,
              child: Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? AppColors.lime : Colors.white70, size: 22),
            ),
            if (keep)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(10)),
                  child: const Text('KEEP', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Text(formatBytes(item.size), style: const TextStyle(fontSize: 11, shadows: [Shadow(blurRadius: 4)])),
            ),
          ],
        ),
      );
    }

    const grid = SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8);

    final Widget content = widget.category == CleanCategory.duplicates
        ? ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: report.duplicateGroups.length,
            itemBuilder: (context, g) {
              final group = report.duplicateGroups[g];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Group ${g + 1} · ${group.length} similar photos', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: group.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => SizedBox(width: 110, child: tile(group[i], keep: i == 0)),
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        : GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            gridDelegate: grid,
            itemCount: all.length,
            itemBuilder: (_, i) => tile(all[i]),
          );

    return Scaffold(
      appBar: AppBar(title: Text(widget.category.title)),
      body: SafeArea(child: all.isEmpty ? const Center(child: Text('Nothing to clean here.')) : content),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
            onPressed: _busy || _selected.isEmpty ? null : () => _delete(report),
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.delete_rounded),
            label: Text(_selected.isEmpty ? 'Select items to delete' : 'Delete ${_selected.length} · ${formatBytes(selectedBytes)}'),
          ),
        ),
      ),
    );
  }
}
