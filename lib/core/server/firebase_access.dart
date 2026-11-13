import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String kFunctionsRegion = 'us-central1';

FirebaseFunctions get appFunctions => FirebaseFunctions.instanceFor(region: kFunctionsRegion);

Future<User>? _signingIn;

/// Anonymous sign-in, shared between concurrent callers.
Future<User> ensureSignedIn() {
  final current = FirebaseAuth.instance.currentUser;
  if (current != null) return Future<User>.value(current);
  return _signingIn ??= _signIn().whenComplete(() => _signingIn = null);
}

Future<User> _signIn() async {
  final cred = await FirebaseAuth.instance.signInAnonymously();
  return cred.user!;
}
