import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

enum VaultAuthResult { success, failed, unsupported }

/// Fingerprint / face unlock. The device PIN or pattern is accepted as a fallback.
class VaultAuth {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<VaultAuthResult> authenticate() async {
    try {
      if (!await _auth.isDeviceSupported()) return VaultAuthResult.unsupported;
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your OMNI Vault',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      return ok ? VaultAuthResult.success : VaultAuthResult.failed;
    } on PlatformException catch (e) {
      // No screen lock / biometrics enrolled: the vault must never open unprotected.
      if (e.code == 'NotAvailable' || e.code == 'PasscodeNotSet' || e.code == 'NotEnrolled') {
        return VaultAuthResult.unsupported;
      }
      return VaultAuthResult.failed;
    }
  }
}

final vaultAuthProvider = Provider<VaultAuth>((ref) => VaultAuth());
