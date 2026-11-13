import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../data/account_repository.dart';
import 'account_providers.dart';

/// Set with --dart-define=PRIVACY_URL=https://... (the hosted privacy policy).
const String _privacyUrl = String.fromEnvironment('PRIVACY_URL');

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final result = await ref.read(accountRepositoryProvider).signInWithGoogle();
    if (mounted) setState(() => _busy = false);
    if (result == SignInResult.failed) _toast('Google sign-in failed. Please try again.');
  }

  Future<void> _signOut() async {
    await ref.read(accountRepositoryProvider).signOut();
    _toast('Signed out.');
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete account and data?'),
        content: const Text(
          'This permanently erases your OMNI account, usage history and subscription records from our servers.\n\n'
          'It does not cancel an active subscription: cancel it in Google Play > Subscriptions.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
      _toast('Your account and data were deleted.');
    } catch (_) {
      _toast('Could not delete the account. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(userProvider).valueOrNull;
    final permanent = user != null && !user.isAnonymous;

    return Scaffold(
      appBar: AppBar(title: const Text('Account & privacy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ListTile(
              leading: Icon(permanent ? Icons.verified_user_rounded : Icons.person_outline_rounded, color: AppColors.violet),
              title: Text(permanent ? (user?.email ?? 'Google account') : 'Guest'),
              subtitle: Text(
                permanent ? 'Your subscription is tied to this account.' : 'Sign in to keep your subscription after a reinstall.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
            ),
            const SizedBox(height: 8),
            if (!permanent)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
                onPressed: _busy ? null : _signIn,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign in with Google'),
              )
            else
              OutlinedButton.icon(
                onPressed: _busy ? null : _signOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            const SizedBox(height: 24),
            FutureBuilder<bool>(
              future: _privacyOptionsRequired(),
              builder: (context, snap) => snap.data == true
                  ? ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Ad privacy settings'),
                      onTap: () => ConsentForm.showPrivacyOptionsForm((FormError? error) {}),
                    )
                  : const SizedBox.shrink(),
            ),
            if (_privacyUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.policy_outlined),
                title: const Text('Privacy policy'),
                onTap: () => launchUrl(Uri.parse(_privacyUrl), mode: LaunchMode.externalApplication),
              ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              title: const Text('Delete account and data'),
              onTap: _busy ? null : _delete,
            ),
          ],
        ),
      ),
    );
  }
}
