import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import 'blocked_screen.dart';
import 'integrity_provider.dart';
import 'integrity_service.dart';

class IntegrityGate extends ConsumerWidget {
  const IntegrityGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final integrity = ref.watch(integrityProvider);
    return integrity.when(
      loading: () => const _Splash(),
      error: (_, __) => child,
      data: (status) => status == IntegrityStatus.blocked ? const BlockedScreen() : child,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('OMNI', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.violet),
            ),
          ],
        ),
      ),
    );
  }
}
