import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/server/server_client.dart';
import '../data/account_repository.dart';

final accountRepositoryProvider =
    Provider<AccountRepository>((ref) => AccountRepository(ref.watch(serverClientProvider)));

/// Fires on sign-in, link, and sign-out (unlike authStateChanges, also when a guest is linked).
final userProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.userChanges());
