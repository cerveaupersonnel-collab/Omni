import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../../core/widgets/glass_card.dart';
import '../../home/domain/home_card_id.dart';
import '../../usage/domain/usage.dart';
import '../../usage/presentation/use_feature.dart';
import 'scan_detail_screen.dart';
import 'scan_providers.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _busy = false;

  Future<void> _scan() async {
    if (_busy) return;
    final session = await beginFeature(context, ref, Feature.scan);
    if (session == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    List<String>? pages;
    try {
      // Google's document scanner: live camera, edge detection, auto-crop and clean-up filters.
      pages = await CunningDocumentScanner.getPictures(noOfPages: 20, isGalleryImportAllowed: true);
    } catch (_) {
      await session.finish(success: false);
      messenger.showSnackBar(const SnackBar(content: Text('The scanner could not start. Please try again.')));
      return;
    }
    if (pages == null || pages.isEmpty) {
      await session.finish(success: false); // cancelled: the free use is given back
      return;
    }

    if (mounted) setState(() => _busy = true);
    try {
      final doc = await ref.read(scansProvider.notifier).addScan(pages);
      await session.finish(success: true);
      if (!mounted) return;
      await navigator.push(MaterialPageRoute<void>(builder: (_) => ScanDetailScreen(doc: doc)));
    } catch (_) {
      await session.finish(success: false);
      messenger.showSnackBar(const SnackBar(content: Text('Could not save the scan.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scans = ref.watch(scansProvider);
    final theme = Theme.of(context);
    return FeatureScaffold(
      card: HomeCardId.scan,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.violet,
        foregroundColor: AppColors.white,
        onPressed: _busy ? null : _scan,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.camera_alt_rounded),
        label: Text(_busy ? 'Reading text…' : 'Scan'),
      ),
      body: scans.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.violet)),
        error: (_, __) => const Center(child: Text('Could not load your scans.')),
        data: (docs) {
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.document_scanner_rounded, size: 72, color: AppColors.violet),
                    const SizedBox(height: 16),
                    Text('Scan your first document', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Edges are detected and cropped automatically. Text is recognized on your device. Export as PDF or JPG.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final doc = docs[i];
              return GlassCard(
                padding: const EdgeInsets.all(12),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ScanDetailScreen(doc: doc))),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(File(doc.pagePaths.firstOrNull ?? doc.pagePaths.first), width: 64, height: 80, fit: BoxFit.cover, cacheWidth: 200),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doc.title, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            '${doc.pagePaths.length} page${doc.pagePaths.length == 1 ? '' : 's'}'
                            '${doc.text.isEmpty ? '' : ' · text recognized'}',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
