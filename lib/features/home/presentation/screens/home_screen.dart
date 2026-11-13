import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../account/presentation/account_screen.dart';
import '../../../ads/presentation/banner_ad_widget.dart';
import '../../../billing/presentation/billing_providers.dart';
import '../../../billing/presentation/paywall_screen.dart';
import '../../../usage/presentation/usage_providers.dart';
import '../../domain/home_card_id.dart';
import '../providers/home_layout_provider.dart';
import 'feature_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = ref.watch(homeLayoutProvider);
    final notifier = ref.read(homeLayoutProvider.notifier);
    final isPro = ref.watch(proStatusProvider).valueOrNull?.isPro ?? false;
    final usage = ref.watch(usageStatusProvider).valueOrNull;
    final ids = _editing ? layout.order : layout.order.where((c) => !layout.hidden.contains(c)).toList();

    return Scaffold(
      bottomNavigationBar: const BannerAdWidget(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(child: Text('OMNI', style: theme.textTheme.headlineMedium)),
                  const _PlanChip(),
                  IconButton(
                    tooltip: 'Account',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen())),
                    icon: const Icon(Icons.account_circle_outlined),
                  ),
                  IconButton(
                    tooltip: _editing ? 'Done' : 'Customize',
                    onPressed: () => setState(() => _editing = !_editing),
                    icon: Icon(
                      _editing ? Icons.check_rounded : Icons.tune_rounded,
                      color: _editing ? AppColors.lime : AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                _editing ? 'Drag to reorder. Toggle to show or hide.' : 'One App. For Everything.',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: ids.isEmpty
                    ? const Center(
                        key: ValueKey('empty'),
                        child: Text('All cards are hidden. Tap customize to show them.'),
                      )
                    : ReorderableListView.builder(
                        key: ValueKey(_editing),
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: ids.length,
                        onReorder: _editing ? notifier.reorder : (_, __) {},
                        itemBuilder: (context, index) {
                          final id = ids[index];
                          final visible = !layout.hidden.contains(id);
                          final used = usage?.used[id.serverName];
                          return Padding(
                            key: ValueKey(id),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Opacity(
                              opacity: visible ? 1 : 0.4,
                              child: GlassCard(
                                onTap: _editing
                                    ? null
                                    : () => Navigator.of(context).push(FeatureScreen.route(id)),
                                child: Row(
                                  children: [
                                    Hero(
                                      tag: 'card-icon-${id.name}',
                                      child: Icon(id.icon, size: 36, color: theme.colorScheme.primary),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(id.title, style: theme.textTheme.titleMedium),
                                          const SizedBox(height: 2),
                                          Text(
                                            id.subtitle,
                                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                                          ),
                                          if (!_editing && !isPro && used != null && usage != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              '$used/${usage.limit} free uses today',
                                              style: theme.textTheme.labelSmall?.copyWith(color: AppColors.lime),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (_editing) ...[
                                      Switch(value: visible, onChanged: (_) => notifier.toggleVisibility(id)),
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(Icons.drag_handle_rounded),
                                        ),
                                      ),
                                    ] else
                                      const Icon(Icons.chevron_right_rounded),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanChip extends ConsumerWidget {
  const _PlanChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pro = ref.watch(proStatusProvider).valueOrNull;
    if (pro == null) return const SizedBox.shrink();
    if (pro.isPro) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(20)),
        child: Text(
          'PRO',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
    }
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.violet,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      onPressed: () => Navigator.of(context).push(PaywallScreen.route()),
      icon: const Icon(Icons.workspace_premium_rounded, size: 18),
      label: const Text('Upgrade'),
    );
  }
}
