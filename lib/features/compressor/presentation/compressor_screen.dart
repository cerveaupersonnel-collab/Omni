import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/platform/media_gateway.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/glass_card.dart';
import '../../home/domain/home_card_id.dart';
import '../../usage/domain/usage.dart';
import '../../usage/presentation/use_feature.dart';
import '../domain/compressor_models.dart';
import 'compressor_controller.dart';

class CompressorScreen extends ConsumerWidget {
  const CompressorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(compressorControllerProvider);
    final controller = ref.read(compressorControllerProvider.notifier);
    final theme = Theme.of(context);
    final info = state.info;
    final busy = state.phase == CompressPhase.compressing;

    Future<void> start() async {
      final session = await beginFeature(context, ref, Feature.compressor);
      if (session == null) return;
      final ok = await controller.compress();
      await session.finish(success: ok);
    }

    return FeatureScaffold(
      card: HomeCardId.compressor,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (info == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const Icon(Icons.movie_filter_rounded, size: 72, color: AppColors.violet),
                  const SizedBox(height: 16),
                  Text('Shrink a video', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Re-encode with hardware H.264 at a smart bitrate: much smaller files that still look great.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            )
          else
            GlassCard(
              child: Row(
                children: [
                  const Icon(Icons.videocam_rounded, color: AppColors.violet, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${info.width}×${info.height} · ${formatDuration(Duration(milliseconds: info.durationMs))}', style: theme.textTheme.titleSmall),
                        Text(formatBytes(info.size), style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: info == null ? AppColors.violet : Colors.white12),
            onPressed: busy || state.phase == CompressPhase.probing ? null : controller.pickVideo,
            icon: const Icon(Icons.video_library_rounded),
            label: Text(info == null ? 'Choose video' : 'Choose another video'),
          ),
          if (state.message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(state.message!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.lime)),
            ),
          if (info != null) ...[
            const SizedBox(height: 24),
            Text('Preset', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final p in VideoPreset.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PresetTile(preset: p, selected: state.preset == p, enabled: !busy, onTap: () => controller.setPreset(p)),
              ),
            if (state.preset == VideoPreset.whatsappStatus && info.durationMs > 30000)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'WhatsApp Status clips are limited to 30 seconds. You will be asked to trim this one when posting.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.lime),
                ),
              ),
            const SizedBox(height: 16),
            if (busy) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: LinearProgressIndicator(
                  value: state.progress == 0 ? null : state.progress / 100,
                  minHeight: 12,
                  color: AppColors.violet,
                  backgroundColor: Colors.white12,
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text('Compressing… ${state.progress}%', style: theme.textTheme.bodyMedium)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: controller.cancel, child: const Text('Cancel')),
            ] else
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
                onPressed: start,
                icon: const Icon(Icons.compress_rounded),
                label: const Text('Compress'),
              ),
          ],
          if (state.phase == CompressPhase.done && state.result != null && info != null)
            _ResultCard(before: info.size, result: state.result!),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, required this.selected, required this.enabled, required this.onTap});
  final VideoPreset preset;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      onTap: enabled ? onTap : null,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? AppColors.violet : Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preset.title, style: theme.textTheme.titleSmall),
                Text(preset.description, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard({required this.before, required this.result});
  final int before;
  final CompressionResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = before == 0 ? 0 : ((1 - result.size / before) * 100).round();
    final smaller = result.size < before;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.lime),
          color: AppColors.lime.withOpacity(0.06),
        ),
        child: Column(
          children: [
            Text(smaller ? '$saved% smaller' : 'Already well optimized', style: theme.textTheme.titleLarge?.copyWith(color: AppColors.lime)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Size('Before', formatBytes(before)),
                const Icon(Icons.arrow_forward_rounded),
                _Size('After', formatBytes(result.size)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Share.shareXFiles([XFile(result.outputPath, mimeType: 'video/mp4')]);
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await ref
                            .read(mediaGatewayProvider)
                            .saveToGallery(result.outputPath, 'OMNI_${DateTime.now().millisecondsSinceEpoch}.mp4', video: true);
                        messenger.showSnackBar(const SnackBar(content: Text('Saved to Movies/OMNI')));
                      } on MediaUnsupportedException catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Size extends StatelessWidget {
  const _Size(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60)),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
