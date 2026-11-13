import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../account/presentation/account_actions.dart';
import '../data/billing_repository.dart';
import '../domain/pro_status.dart';
import 'billing_providers.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const PaywallScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      );

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selected = BillingRepository.yearlyId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final billing = ref.watch(billingControllerProvider);
    final productsAsync = ref.watch(productsProvider);
    final pro = ref.watch(proStatusProvider).valueOrNull ?? ProStatus.free;

    ref.listen<BillingUiState>(billingControllerProvider, (prev, next) {
      if (next.eventId == prev?.eventId || next.message == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.message!)));
    });
    ref.listen<AsyncValue<ProStatus>>(proStatusProvider, (prev, next) {
      final was = prev?.valueOrNull?.isPro ?? false;
      final now = next.valueOrNull?.isPro ?? false;
      if (!was && now) Navigator.of(context).maybePop();
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1),
            radius: 1.2,
            colors: [AppColors.violet.withOpacity(0.35), AppColors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, size: 72, color: AppColors.lime),
                      const SizedBox(height: 16),
                      Text('OMNI Pro', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        'One App. For Everything. Without limits.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      const _Benefit(icon: Icons.all_inclusive_rounded, text: 'Unlimited use of every tool'),
                      const _Benefit(icon: Icons.block_rounded, text: 'No ads'),
                      const _Benefit(icon: Icons.bolt_rounded, text: 'Priority AI with longer answers'),
                      const SizedBox(height: 24),
                      if (pro.isPro)
                        _ProActiveCard(expiresAt: pro.expiresAt)
                      else
                        productsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(color: AppColors.violet),
                          ),
                          error: (_, __) => _PlansUnavailable(onRetry: () => ref.invalidate(productsProvider)),
                          data: _buildPlans,
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _buildBottom(theme, billing, productsAsync.valueOrNull, pro),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlans(List<ProductDetails> products) {
    final monthly = products.where((p) => p.id == BillingRepository.monthlyId).firstOrNull;
    final yearly = products.where((p) => p.id == BillingRepository.yearlyId).firstOrNull;

    String? savings;
    if (monthly != null && yearly != null && monthly.rawPrice > 0) {
      final pct = (1 - yearly.rawPrice / (monthly.rawPrice * 12)) * 100;
      if (pct >= 1) savings = 'Save ${pct.round()}%';
    }

    return Column(
      children: [
        if (yearly != null)
          _PlanCard(
            title: 'Yearly',
            price: '${yearly.price} / year',
            detail: '${yearly.currencySymbol}${(yearly.rawPrice / 12).toStringAsFixed(2)} / month',
            badge: savings == null ? 'BEST VALUE' : 'BEST VALUE · $savings',
            selected: _selected == yearly.id,
            onTap: () => setState(() => _selected = yearly.id),
          ),
        if (yearly != null && monthly != null) const SizedBox(height: 12),
        if (monthly != null)
          _PlanCard(
            title: 'Monthly',
            price: '${monthly.price} / month',
            detail: 'Cancel anytime',
            selected: _selected == monthly.id,
            onTap: () => setState(() => _selected = monthly.id),
          ),
      ],
    );
  }

  Widget _buildBottom(ThemeData theme, BillingUiState billing, List<ProductDetails>? products, ProStatus pro) {
    final selected = products?.where((p) => p.id == _selected).firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!pro.isPro)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.violet, foregroundColor: AppColors.white),
              onPressed: billing.busy || selected == null
                  ? null
                  : () async {
                      if (!await ensurePermanentAccount(context, ref)) return;
                      ref.read(billingControllerProvider.notifier).buy(selected);
                    },
              child: billing.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                    )
                  : const Text('Continue'),
            ),
          TextButton(
            onPressed: billing.busy
                ? null
                : () async {
                    if (!await ensurePermanentAccount(context, ref)) return;
                    ref.read(billingControllerProvider.notifier).restore();
                  },
            child: const Text('Restore Purchase'),
          ),
          Text(
            'Subscriptions renew automatically until canceled. Manage or cancel anytime in Google Play > Subscriptions.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.lime, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final String detail;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppTheme.radius);
    return Semantics(
      button: true,
      selected: selected,
      label: '$title plan, $price',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: radius,
          color: Colors.white.withOpacity(selected ? 0.10 : 0.05),
          border: Border.all(
            color: selected ? AppColors.violet : Colors.white.withOpacity(0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? AppColors.violet : Colors.white54,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (badge != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.lime,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badge!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.black,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Text(title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60)),
                      ],
                    ),
                  ),
                  Text(price, style: theme.textTheme.titleSmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProActiveCard extends StatelessWidget {
  const _ProActiveCard({this.expiresAt});
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String two(int n) => n.toString().padLeft(2, '0');
    final date = expiresAt == null ? null : '${expiresAt!.year}-${two(expiresAt!.month)}-${two(expiresAt!.day)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.lime),
        color: AppColors.lime.withOpacity(0.08),
      ),
      child: Column(
        children: [
          Text("You're OMNI Pro", style: theme.textTheme.titleLarge),
          if (date != null) ...[
            const SizedBox(height: 6),
            Text('Active until $date', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          ],
          const SizedBox(height: 6),
          Text(
            'Manage your subscription in Google Play.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _PlansUnavailable extends StatelessWidget {
  const _PlansUnavailable({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Plans are unavailable right now. Check your connection and Google Play, then try again.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
