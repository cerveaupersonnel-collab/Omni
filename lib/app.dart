import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/security/integrity_gate.dart';
import 'core/theme/app_theme.dart';
import 'features/billing/presentation/billing_providers.dart';
import 'features/home/presentation/screens/home_screen.dart';

class OmniApp extends ConsumerStatefulWidget {
  const OmniApp({super.key});

  @override
  ConsumerState<OmniApp> createState() => _OmniAppState();
}

class _OmniAppState extends ConsumerState<OmniApp> {
  @override
  void initState() {
    super.initState();
    // Start listening to the Play purchase stream as early as possible so that
    // pending purchases from a previous session are processed.
    ref.read(billingControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMNI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const IntegrityGate(child: HomeScreen()),
    );
  }
}
