import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feature_scaffold.dart';
import '../../billing/presentation/paywall_screen.dart';
import '../../home/domain/home_card_id.dart';
import 'chat_pdf_controller.dart';

const _languages = [
  'English', 'Spanish', 'French', 'Haitian Creole', 'Portuguese', 'German', 'Italian', 'Arabic', 'Chinese', 'Hindi', 'Russian',
];

class ChatPdfScreen extends ConsumerStatefulWidget {
  const ChatPdfScreen({super.key});

  @override
  ConsumerState<ChatPdfScreen> createState() => _ChatPdfScreenState();
}

class _ChatPdfScreenState extends ConsumerState<ChatPdfScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<ChatOutcome> Function() action) async {
    final navigator = Navigator.of(context);
    final future = action();
    _scrollToEnd();
    final outcome = await future;
    _scrollToEnd();
    if (outcome == ChatOutcome.limitReached && mounted) {
      await navigator.push(PaywallScreen.route());
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _translate() async {
    final language = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(24, 0, 24, 8), child: Text('Translate to…')),
            for (final l in _languages) ListTile(title: Text(l), onTap: () => Navigator.pop(c, l)),
          ],
        ),
      ),
    );
    if (language == null) return;
    await _run(() => ref.read(chatPdfControllerProvider.notifier).translate(language));
  }

  void _submit() {
    final q = _input.text.trim();
    if (q.isEmpty) return;
    _input.clear();
    _run(() => ref.read(chatPdfControllerProvider.notifier).ask(q));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatPdfControllerProvider);
    final controller = ref.read(chatPdfControllerProvider.notifier);
    final theme = Theme.of(context);

    return FeatureScaffold(
      card: HomeCardId.chatPdf,
      actions: [
        if (state.hasPdf)
          IconButton(tooltip: 'Choose another PDF', onPressed: controller.pickPdf, icon: const Icon(Icons.swap_horiz_rounded)),
      ],
      body: !state.hasPdf
          ? _EmptyState(state: state, onPick: controller.pickPdf)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.violet),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${state.fileName} · ${state.pages} pages',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.notice != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(state.notice!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.lime)),
                  ),
                Expanded(
                  child: state.messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'Ask anything about this document, or use a quick action below.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: state.messages.length + (state.sending ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == state.messages.length) return const _Bubble(fromUser: false, text: 'Thinking…');
                            final m = state.messages[i];
                            return _Bubble(fromUser: m.fromUser, text: m.text, isError: m.isError);
                          },
                        ),
                ),
                if (state.remaining != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${state.remaining} free AI uses left today',
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54),
                    ),
                  ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _ActionChip(label: 'Summarize', icon: Icons.notes_rounded, onTap: state.sending ? null : () => _run(controller.summarize)),
                      _ActionChip(label: 'Translate', icon: Icons.translate_rounded, onTap: state.sending ? null : _translate),
                      _ActionChip(label: 'Find Tables', icon: Icons.table_chart_rounded, onTap: state.sending ? null : () => _run(controller.findTables)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Ask a question…',
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radius),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: AppColors.violet),
                        onPressed: state.sending ? null : _submit,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state, required this.onPick});
  final ChatPdfState state;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_rounded, size: 72, color: AppColors.violet),
            const SizedBox(height: 16),
            Text('Chat with any PDF', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Upload a PDF (up to 50 MB). Its text is extracted on your device and sent to the AI only when you ask.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            if (state.notice != null) ...[
              const SizedBox(height: 12),
              Text(state.notice!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.lime)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
              onPressed: state.loadingPdf ? null : onPick,
              icon: state.loadingPdf
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file_rounded),
              label: Text(state.loadingPdf ? 'Reading PDF…' : 'Choose PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.fromUser, required this.text, this.isError = false});
  final bool fromUser;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: fromUser ? AppColors.violet : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: isError ? Border.all(color: Colors.redAccent) : null,
        ),
        child: SelectableText(text, style: theme.textTheme.bodyMedium),
      ),
    );
  }
}
