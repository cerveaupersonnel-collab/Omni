import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/server/firebase_access.dart';
import '../../../core/server/server_client.dart';

enum SignInResult { signedIn, cancelled, failed }

class AccountRepository {
  AccountRepository(this._server);
  final ServerClient _server;
  final GoogleSignIn _google = GoogleSignIn(scopes: ['email']);

  User? get user => FirebaseAuth.instance.currentUser;
  bool get isPermanent => user != null && !user!.isAnonymous;

  /// Links the guest account to Google. If that Google account already exists (for example
  /// after a reinstall) the app switches to it, so the subscription is found again.
  Future<SignInResult> signInWithGoogle() async {
    try {
      final account = await _google.signIn();
      if (account == null) return SignInResult.cancelled;
      final tokens = await account.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: tokens.accessToken, idToken: tokens.idToken);

      final current = await ensureSignedIn();
      if (current.isAnonymous) {
        try {
          await current.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
            await FirebaseAuth.instance.signInWithCredential(e.credential ?? credential);
          } else {
            rethrow;
          }
        }
      }
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      return SignInResult.signedIn;
    } on FirebaseAuthException {
      return SignInResult.failed;
    } on PlatformException {
      return SignInResult.failed;
    }
  }

  Future<void> signOut() async {
    await _google.signOut();
    await FirebaseAuth.instance.signOut();
  }

  /// Erases server data and the Firebase account. A running subscription is NOT cancelled
  /// by this: the user cancels it in Google Play.
  Future<void> deleteAccount() async {
    await _server.call('deleteAccount');
    await signOut();
  }
}
