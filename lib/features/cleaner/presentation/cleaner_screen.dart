import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/media_gateway.dart';
import '../../../core/platform/system_channel.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/glass_card.dart';
import '../../home/domain/home_card_id.dart';
import '../../usage/domain/usage.dart';
import '../../usage/presentation/use_feature.dart';
import 'category_screen.dart';
import 'cleaner_controller.dart';
import 'storage_donut.dart';

class CleanerScreen extends ConsumerStatefulWidget {
  const CleanerScreen({super.key});

  @override
  ConsumerState<CleanerScreen> createState() => _CleanerScreenState();
}

class _CleanerScreenState extends ConsumerState<CleanerScreen> {
  Future<void> _begin() async {
    final controller = ref.read(cleanerControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    if (!await controller.isSupported()) {
      messenger.showSnackBar(const SnackBar(content: Text('Omni Clean needs Android 11 or newer.')));
      return;
    }
    if (!mounted) return;
    if (!await controller.hasPermission()) {
      final agree = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Allow access to photos and videos?'),
          content: const Text(
            'OMNI Clean looks through your photos and videos to find duplicates, blurry shots, large videos and WhatsApp media.\n\n'
            '• Everything is analyzed on your device. Nothing is uploaded.\n'
            '• Nothing is deleted until you confirm in an Android system dialog.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continue')),
          ],
        ),
      );
      if (agree != true) return;
      if (!await controller.requestPermission()) {
        messenger.showSnackBar(SnackBar(
          content: const Text('Permission is needed to scan. Allow access to all photos and videos in Settings.'),
          action: SnackBarAction(label: 'Settings', onPressed: SystemChannel.openAppSettings),
        ));
        return;
      }
    }
    if (!mounted) return;
    final session = await beginFeature(context, ref, Feature.cleaner);
    if (session == null) return;
    final ok = await controller.scan();
    await session.finish(success: ok);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cleanerControllerProvider);
    final theme = Theme.of(context);
    final report = state.report;
    final storage = state.storage;

    Widget body;
    if (state.phase == CleanerPhase.scanning && report == null) {
      body = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.violet),
            SizedBox(height: 16),
            Text('Analyzing your photos and videos…'),
            SizedBox(height: 4),
            Text('This can take a moment on large galleries.', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    } else if (report == null || storage == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cleaning_services_rounded, size: 72, color: AppColors.violet),
              const SizedBox(height: 16),
              Text('Free up space', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                state.phase == CleanerPhase.error
                    ? 'Something went wrong while scanning. Please try again.'
                    : 'Find duplicate and blurry photos, large videos and WhatsApp media. You approve every deletion.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
                onPressed: _begin,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Scan my phone'),
              ),
            ],
          ),
        ),
      );
    } else {
      final other = (storage.used - report.imageBytes - report.videoBytes).clamp(0, storage.total);
      final reclaimable = report.duplicateBytes + report.blurryBytes + report.largeVideoBytes + report.whatsappBytes;
      body = RefreshIndicator(
        onRefresh: _begin,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: StorageDonut(
                centerTop: formatBytes(storage.used),
                centerBottom: 'of ${formatBytes(storage.total)} used',
                segments: [
                  DonutSegment(report.imageBytes.toDouble(), AppColors.violet),
                  DonutSegment(report.videoBytes.toDouble(), AppColors.lime),
                  DonutSegment(other.toDouble(), Colors.white38),
                  DonutSegment(storage.free.toDouble(), Colors.white12),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 6,
              children: [
                _Legend(AppColors.violet, 'Photos ${formatBytes(report.imageBytes)}'),
                _Legend(AppColors.lime, 'Videos ${formatBytes(report.videoBytes)}'),
                _Legend(Colors.white38, 'Other ${formatBytes(other)}'),
                _Legend(Colors.white12, 'Free ${formatBytes(storage.free)}'),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Up to ${formatBytes(reclaimable)} can be reclaimed',
                style: theme.textTheme.titleMedium?.copyWith(color: AppColors.lime),
              ),
            ),
            const SizedBox(height: 16),
            _CategoryTile(
              icon: Icons.content_copy_rounded,
              title: 'Duplicate photos',
              subtitle: '${report.duplicateCount} extra copies',
              bytes: report.duplicateBytes,
              onTap: () => _open(CleanCategory.duplicates),
            ),
            _CategoryTile(
              icon: Icons.blur_on_rounded,
              title: 'Blurry photos',
              subtitle: '${report.blurry.length} possibly blurry',
              bytes: report.blurryBytes,
              onTap: () => _open(CleanCategory.blurry),
            ),
            _CategoryTile(
              icon: Icons.movie_rounded,
              title: 'Large videos',
              subtitle: '${report.largeVideos.length} videos over 50 MB',
              bytes: report.largeVideoBytes,
              onTap: () => _open(CleanCategory.largeVideos),
            ),
            _CategoryTile(
              icon: Icons.chat_rounded,
              title: 'WhatsApp media',
              subtitle: '${report.whatsapp.length} received files',
              bytes: report.whatsappBytes,
              onTap: () => _open(CleanCategory.whatsapp),
            ),
            const SizedBox(height: 8),
            Text(
              'Blurry detection is an estimate: review before deleting. APK files and WhatsApp documents are not scanned '
              'because Google Play does not allow cleaner apps to read all files.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return FeatureScaffold(
      card: HomeCardId.cleaner,
      actions: [
        if (report != null)
          IconButton(
            tooltip: 'Rescan',
            onPressed: state.phase == CleanerPhase.scanning ? null : () => ref.read(cleanerControllerProvider.notifier).scan(),
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
      body: Stack(
        children: [
          body,
          if (state.phase == CleanerPhase.scanning && report != null) const LinearProgressIndicator(color: AppColors.violet),
        ],
      ),
    );
  }

  void _open(CleanCategory category) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CategoryScreen(category: category)));
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.icon, required this.title, required this.subtitle, required this.bytes, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final int bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: bytes == 0 ? null : onTap,
        child: Row(
          children: [
            Icon(icon, color: AppColors.violet, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60)),
                ],
              ),
            ),
            Text(formatBytes(bytes), style: theme.textTheme.titleSmall?.copyWith(color: AppColors.lime)),
          ],
        ),
      ),
    );
  }
}
