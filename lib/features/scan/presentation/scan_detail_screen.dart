import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/scan_doc.dart';
import 'scan_providers.dart';

class ScanDetailScreen extends ConsumerStatefulWidget {
  const ScanDetailScreen({super.key, required this.doc});
  final ScanDoc doc;

  @override
  ConsumerState<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends ConsumerState<ScanDetailScreen> {
  bool _exporting = false;

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final path = await ref.read(scanRepositoryProvider).exportPdf(widget.doc);
      await Share.shareXFiles([XFile(path, mimeType: 'application/pdf')], subject: widget.doc.title);
    } catch (_) {
      _toast('Could not export the PDF.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportJpg() async {
    try {
      final result = await Share.shareXFiles(
        widget.doc.pagePaths.map((p) => XFile(p, mimeType: 'image/jpeg')).toList(),
        subject: widget.doc.title,
      );
    } catch (_) {
      _toast('Could not export the images.');
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this scan?'),
        content: const Text('The pages and recognized text will be removed from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(scansProvider.notifier).remove(widget.doc);
    navigator.pop();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(doc.title),
          actions: [
            IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Pages'), Tab(text: 'Text')]),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: TabBarView(
                  children: [
                    PageView.builder(
                      itemCount: doc.pagePaths.length,
                      itemBuilder: (_, i) => InteractiveViewer(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.file(File(doc.pagePaths[i]), fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                    doc.text.isEmpty
                        ? const Center(child: Text('No text was recognized in this scan.'))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: SelectableText(doc.text, style: Theme.of(context).textTheme.bodyMedium),
                          ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _exporting ? null : _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exportJpg,
                        icon: const Icon(Icons.image_rounded),
                        label: const Text('JPG'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Copy text',
                      onPressed: doc.text.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(ClipboardData(text: doc.text));
                              _toast('Text copied');
                            },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
