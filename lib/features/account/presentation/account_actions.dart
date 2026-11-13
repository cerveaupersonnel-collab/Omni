import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_repository.dart';
import 'account_providers.dart';

/// Subscriptions require a Google account so they can be restored after a reinstall.
/// Returns true when the user is (now) signed in with Google.
Future<bool> ensurePermanentAccount(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(accountRepositoryProvider);
  if (repo.isPermanent) return true;

  final messenger = ScaffoldMessenger.of(context);
  final agree = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Sign in to keep your subscription'),
      content: const Text(
        'Sign in with Google so your OMNI Pro subscription follows you if you reinstall the app or change phones. '
        'Your Google account is only used to identify your purchase.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continue with Google')),
      ],
    ),
  );
  if (agree != true) return false;

  final result = await repo.signInWithGoogle();
  if (result == SignInResult.failed) {
    messenger.showSnackBar(const SnackBar(content: Text('Google sign-in failed. Please try again.')));
  }
  return result == SignInResult.signedIn;
}
