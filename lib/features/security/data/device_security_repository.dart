import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/result.dart';
import '../domain/security_repository.dart';

class DeviceSecurityRepository implements SecurityRepository {
  DeviceSecurityRepository({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();
  final LocalAuthentication _localAuth;

  @override
  Future<Result<bool>> authenticate() async {
    try {
      if (!await _localAuth.canCheckBiometrics) return const Success(false);
      return Success(
        await _localAuth.authenticate(
          localizedReason: 'Déverrouiller PeMS Store',
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        ),
      );
    } catch (error) {
      return Failure(
        AppFailure('Authentification indisponible.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> setPin(String pin) async {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      return const Failure(AppFailure('Le PIN doit contenir 4 à 6 chiffres.'));
    }
    final salt = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    final digest = sha256.convert([...salt, ...utf8.encode(pin)]).toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pinSalt', base64Encode(salt));
    await prefs.setString('pinDigest', digest);
    return const Success(null);
  }

  @override
  Future<Result<bool>> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('pinDigest');
    final encodedSalt = prefs.getString('pinSalt');
    if (stored == null || encodedSalt == null) return const Success(false);
    final digest = sha256.convert([
      ...base64Decode(encodedSalt),
      ...utf8.encode(pin),
    ]).toString();
    return Success(stored == digest);
  }
}
