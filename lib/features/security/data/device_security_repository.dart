import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/result.dart';
import '../domain/security_repository.dart';

typedef PreferencesLoader = Future<SharedPreferences> Function();
typedef RetryDelay = Future<void> Function(Duration duration);
typedef Clock = DateTime Function();
typedef RandomBytes = List<int> Function(int length);

class DeviceSecurityRepository implements SecurityRepository {
  DeviceSecurityRepository({
    LocalAuthentication? localAuth,
    PreferencesLoader? preferencesLoader,
    RetryDelay? retryDelay,
    Clock? clock,
    RandomBytes? randomBytes,
    this.passwordIterations = 120000,
  }) : _localAuth = localAuth ?? LocalAuthentication(),
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _retryDelay =
           retryDelay ?? ((duration) => Future<void>.delayed(duration)),
       _clock = clock ?? DateTime.now,
       _randomBytes = randomBytes ?? _secureRandomBytes;

  static const _identifierKey = 'auth.identifier';
  static const _saltKey = 'auth.passwordSalt';
  static const _passwordHashKey = 'auth.passwordHash';
  static const _iterationsKey = 'auth.passwordIterations';
  static const _accessTokenKey = 'auth.session.accessToken';
  static const _accessExpiryKey = 'auth.session.accessExpiresAt';
  static const _refreshTokenKey = 'auth.session.refreshToken';
  static const _refreshExpiryKey = 'auth.session.refreshExpiresAt';
  static const _signatureKey = 'auth.session.signature';
  static const _rememberKey = 'auth.session.rememberMe';

  final LocalAuthentication _localAuth;
  final PreferencesLoader _preferencesLoader;
  final RetryDelay _retryDelay;
  final Clock _clock;
  final RandomBytes _randomBytes;
  final int passwordIterations;
  _SessionRecord? _volatileSession;

  @override
  Future<Result<bool>> hasCredentials() async {
    try {
      final prefs = await _loadPreferences();
      return Success(_credentialsAreComplete(prefs));
    } catch (error) {
      return Failure(
        AppFailure('Impossible de vérifier le compte local.', cause: error),
      );
    }
  }

  @override
  Future<Result<String?>> savedIdentifier() async {
    try {
      final prefs = await _loadPreferences();
      return Success(prefs.getString(_identifierKey));
    } catch (error) {
      return Failure(
        AppFailure('Identifiant local indisponible.', cause: error),
      );
    }
  }

  @override
  Future<Result<AuthSession>> register({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    final validation = _validateCredentials(identifier, password);
    if (validation != null) return Failure(validation);
    try {
      final prefs = await _loadPreferences();
      if (_credentialsAreComplete(prefs)) {
        return const Failure(
          AppFailure('Un compte propriétaire existe déjà sur cet appareil.'),
        );
      }
      final normalizedIdentifier = identifier.trim();
      final salt = _randomBytes(32);
      final derived = await _derivePassword(password, salt, passwordIterations);
      final saved = await Future.wait([
        prefs.setString(_identifierKey, normalizedIdentifier),
        prefs.setString(_saltKey, base64UrlEncode(salt)),
        prefs.setString(_passwordHashKey, base64UrlEncode(derived)),
        prefs.setInt(_iterationsKey, passwordIterations),
      ]);
      if (saved.any((value) => !value)) {
        return const Failure(
          AppFailure('Impossible d’enregistrer les identifiants.'),
        );
      }
      return await _createSession(
        prefs: prefs,
        identifier: normalizedIdentifier,
        passwordKey: derived,
        rememberMe: rememberMe,
      );
    } catch (error) {
      return Failure(
        AppFailure('Création du compte impossible.', cause: error),
      );
    }
  }

  @override
  Future<Result<AuthSession>> signIn({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    if (identifier.trim().isEmpty || password.isEmpty) {
      return const Failure(
        AppFailure('Saisissez votre identifiant et votre mot de passe.'),
      );
    }
    try {
      final prefs = await _loadPreferences();
      final verified = await _verifyCredentials(prefs, identifier, password);
      if (verified == null) {
        return const Failure(
          AppFailure('Identifiant ou mot de passe incorrect.'),
        );
      }
      await _clearPersistedSession(prefs);
      return await _createSession(
        prefs: prefs,
        identifier: prefs.getString(_identifierKey)!,
        passwordKey: verified,
        rememberMe: rememberMe,
      );
    } catch (error) {
      return Failure(AppFailure('Connexion impossible.', cause: error));
    }
  }

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    try {
      final prefs = await _loadPreferences();
      final record = _volatileSession ?? _readPersistedSession(prefs);
      if (record == null) return const Success(null);
      final passwordKey = _readPasswordKey(prefs);
      if (passwordKey == null || !_sessionIsValid(record, passwordKey)) {
        await _clearSession(prefs);
        return const Success(null);
      }
      final now = _clock();
      if (!record.refreshExpiresAt.isAfter(now)) {
        await _clearSession(prefs);
        return const Success(null);
      }
      if (!record.accessExpiresAt.isAfter(now.add(refreshTokenLeeway))) {
        return Success(await _rotateSession(prefs, record, passwordKey));
      }
      return Success(record.toDomain());
    } catch (error) {
      return Failure(
        AppFailure('Restauration de la session impossible.', cause: error),
      );
    }
  }

  @override
  Future<Result<AuthSession>> refreshSession() async {
    try {
      final prefs = await _loadPreferences();
      final record = _volatileSession ?? _readPersistedSession(prefs);
      final passwordKey = _readPasswordKey(prefs);
      if (record == null ||
          passwordKey == null ||
          !_sessionIsValid(record, passwordKey) ||
          !record.refreshExpiresAt.isAfter(_clock())) {
        await _clearSession(prefs);
        return const Failure(
          AppFailure('Votre session a expiré. Reconnectez-vous.'),
        );
      }
      return Success(await _rotateSession(prefs, record, passwordKey));
    } catch (error) {
      return Failure(
        AppFailure('Renouvellement de la session impossible.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _clearSession(await _loadPreferences());
      return const Success(null);
    } catch (error) {
      return Failure(AppFailure('Déconnexion impossible.', cause: error));
    }
  }

  @override
  Future<Result<AuthSession>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final passwordValidation = _validatePassword(newPassword);
    if (passwordValidation != null) return Failure(passwordValidation);
    try {
      final prefs = await _loadPreferences();
      final identifier = prefs.getString(_identifierKey);
      if (identifier == null ||
          await _verifyCredentials(prefs, identifier, currentPassword) ==
              null) {
        return const Failure(
          AppFailure('Le mot de passe actuel est incorrect.'),
        );
      }
      final rememberMe =
          (_volatileSession ?? _readPersistedSession(prefs))?.rememberMe ??
          true;
      final salt = _randomBytes(32);
      final derived = await _derivePassword(
        newPassword,
        salt,
        passwordIterations,
      );
      await Future.wait([
        prefs.setString(_saltKey, base64UrlEncode(salt)),
        prefs.setString(_passwordHashKey, base64UrlEncode(derived)),
        prefs.setInt(_iterationsKey, passwordIterations),
      ]);
      await _clearSession(prefs);
      return await _createSession(
        prefs: prefs,
        identifier: identifier,
        passwordKey: derived,
        rememberMe: rememberMe,
      );
    } catch (error) {
      return Failure(
        AppFailure('Modification du mot de passe impossible.', cause: error),
      );
    }
  }

  @override
  Future<Result<bool>> authenticateBiometrics() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return const Success(false);
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
  Future<Result<AuthSession>> signInWithBiometrics({
    required bool rememberMe,
  }) async {
    final authentication = await authenticateBiometrics();
    final failure = authentication.fold((value) => value, (_) => null);
    if (failure != null) return Failure(failure);
    final authenticated = authentication.fold((_) => false, (ok) => ok);
    if (!authenticated) {
      return const Failure(AppFailure('Authentification annulée.'));
    }
    try {
      final prefs = await _loadPreferences();
      final identifier = prefs.getString(_identifierKey);
      final passwordKey = _readPasswordKey(prefs);
      if (identifier == null || passwordKey == null) {
        return const Failure(AppFailure('Compte local introuvable.'));
      }
      await _clearSession(prefs);
      return await _createSession(
        prefs: prefs,
        identifier: identifier,
        passwordKey: passwordKey,
        rememberMe: rememberMe,
      );
    } catch (error) {
      return Failure(
        AppFailure('Connexion biométrique impossible.', cause: error),
      );
    }
  }

  Future<Result<AuthSession>> _createSession({
    required SharedPreferences prefs,
    required String identifier,
    required List<int> passwordKey,
    required bool rememberMe,
  }) async {
    final now = _clock();
    final unsigned = _SessionRecord(
      identifier: identifier,
      accessToken: _token(32),
      accessExpiresAt: now.add(accessTokenLifetime),
      refreshToken: _token(48),
      refreshExpiresAt: now.add(refreshTokenLifetime),
      rememberMe: rememberMe,
      signature: '',
    );
    final record = unsigned.withSignature(_signSession(unsigned, passwordKey));
    if (!await _storeSession(prefs, record)) {
      return const Failure(
        AppFailure('Impossible d’enregistrer la nouvelle session.'),
      );
    }
    return Success(record.toDomain());
  }

  Future<SharedPreferences> _loadPreferences() async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _preferencesLoader();
      } catch (error, stackTrace) {
        final shouldRetry =
            attempt < maxAttempts && _isTransientChannelError(error);
        developer.log(
          shouldRetry
              ? 'Preferences channel unavailable; retrying ($attempt/$maxAttempts).'
              : 'Unable to load local authentication preferences.',
          name: 'pems.security',
          error: error,
          stackTrace: stackTrace,
        );
        if (!shouldRetry) Error.throwWithStackTrace(error, stackTrace);
        await _retryDelay(Duration(milliseconds: 150 * attempt));
      }
    }
    throw StateError('Preferences loader exhausted its retry attempts.');
  }

  bool _isTransientChannelError(Object error) {
    if (error is MissingPluginException) return true;
    if (error is PlatformException) {
      final details = '${error.code} ${error.message}'.toLowerCase();
      return details.contains('channel-error') ||
          details.contains('unable to establish connection on channel');
    }
    final details = error.toString().toLowerCase();
    return details.contains('missingpluginexception') ||
        details.contains('unable to establish connection on channel');
  }

  Future<AuthSession> _rotateSession(
    SharedPreferences prefs,
    _SessionRecord previous,
    List<int> passwordKey,
  ) async {
    final now = _clock();
    final unsigned = _SessionRecord(
      identifier: previous.identifier,
      accessToken: _token(32),
      accessExpiresAt: now.add(accessTokenLifetime),
      refreshToken: _token(48),
      refreshExpiresAt: now.add(refreshTokenLifetime),
      rememberMe: previous.rememberMe,
      signature: '',
    );
    final record = unsigned.withSignature(_signSession(unsigned, passwordKey));
    if (!await _storeSession(prefs, record)) {
      throw StateError('Session storage failed');
    }
    return record.toDomain();
  }

  Future<bool> _storeSession(
    SharedPreferences prefs,
    _SessionRecord record,
  ) async {
    _volatileSession = record;
    if (!record.rememberMe) {
      await _clearPersistedSession(prefs);
      return true;
    }
    final results = await Future.wait([
      prefs.setString(_accessTokenKey, record.accessToken),
      prefs.setString(
        _accessExpiryKey,
        record.accessExpiresAt.toUtc().toIso8601String(),
      ),
      prefs.setString(_refreshTokenKey, record.refreshToken),
      prefs.setString(
        _refreshExpiryKey,
        record.refreshExpiresAt.toUtc().toIso8601String(),
      ),
      prefs.setString(_signatureKey, record.signature),
      prefs.setBool(_rememberKey, true),
    ]);
    return results.every((value) => value);
  }

  _SessionRecord? _readPersistedSession(SharedPreferences prefs) {
    if (prefs.getBool(_rememberKey) != true) return null;
    final identifier = prefs.getString(_identifierKey);
    final accessToken = prefs.getString(_accessTokenKey);
    final accessExpiresAt = DateTime.tryParse(
      prefs.getString(_accessExpiryKey) ?? '',
    );
    final refreshToken = prefs.getString(_refreshTokenKey);
    final refreshExpiresAt = DateTime.tryParse(
      prefs.getString(_refreshExpiryKey) ?? '',
    );
    final signature = prefs.getString(_signatureKey);
    if (identifier == null ||
        accessToken == null ||
        accessExpiresAt == null ||
        refreshToken == null ||
        refreshExpiresAt == null ||
        signature == null) {
      return null;
    }
    return _SessionRecord(
      identifier: identifier,
      accessToken: accessToken,
      accessExpiresAt: accessExpiresAt,
      refreshToken: refreshToken,
      refreshExpiresAt: refreshExpiresAt,
      rememberMe: true,
      signature: signature,
    );
  }

  bool _sessionIsValid(_SessionRecord record, List<int> passwordKey) =>
      _constantTimeEquals(
        utf8.encode(record.signature),
        utf8.encode(_signSession(record, passwordKey)),
      );

  String _signSession(_SessionRecord record, List<int> passwordKey) {
    final payload = [
      record.identifier,
      record.accessToken,
      record.accessExpiresAt.toUtc().toIso8601String(),
      record.refreshToken,
      record.refreshExpiresAt.toUtc().toIso8601String(),
      record.rememberMe.toString(),
    ].join('|');
    return Hmac(sha256, passwordKey).convert(utf8.encode(payload)).toString();
  }

  Future<List<int>?> _verifyCredentials(
    SharedPreferences prefs,
    String identifier,
    String password,
  ) async {
    final storedIdentifier = prefs.getString(_identifierKey);
    final salt = _decode(prefs.getString(_saltKey));
    final expected = _decode(prefs.getString(_passwordHashKey));
    final iterations = prefs.getInt(_iterationsKey);
    if (storedIdentifier == null ||
        salt == null ||
        expected == null ||
        iterations == null) {
      return null;
    }
    final sameIdentifier =
        storedIdentifier.toLowerCase() == identifier.trim().toLowerCase();
    final actual = await _derivePassword(password, salt, iterations);
    return sameIdentifier && _constantTimeEquals(expected, actual)
        ? actual
        : null;
  }

  List<int>? _readPasswordKey(SharedPreferences prefs) =>
      _decode(prefs.getString(_passwordHashKey));

  bool _credentialsAreComplete(SharedPreferences prefs) =>
      prefs.getString(_identifierKey)?.isNotEmpty == true &&
      _decode(prefs.getString(_saltKey)) != null &&
      _decode(prefs.getString(_passwordHashKey)) != null &&
      (prefs.getInt(_iterationsKey) ?? 0) > 0;

  AppFailure? _validateCredentials(String identifier, String password) {
    final trimmed = identifier.trim();
    if (trimmed.length < 3 || trimmed.length > 80) {
      return const AppFailure(
        'L’identifiant doit contenir entre 3 et 80 caractères.',
      );
    }
    return _validatePassword(password);
  }

  AppFailure? _validatePassword(String password) {
    if (password.length < 8) {
      return const AppFailure(
        'Le mot de passe doit contenir au moins 8 caractères.',
      );
    }
    if (password.length > 128) {
      return const AppFailure('Le mot de passe est trop long.');
    }
    return null;
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    _volatileSession = null;
    await _clearPersistedSession(prefs);
  }

  Future<void> _clearPersistedSession(SharedPreferences prefs) async {
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_accessExpiryKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_refreshExpiryKey),
      prefs.remove(_signatureKey),
      prefs.remove(_rememberKey),
    ]);
  }

  String _token(int length) =>
      base64UrlEncode(_randomBytes(length)).replaceAll('=', '');

  static List<int> _secureRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

class _SessionRecord {
  const _SessionRecord({
    required this.identifier,
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
    required this.rememberMe,
    required this.signature,
  });

  final String identifier;
  final String accessToken;
  final DateTime accessExpiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;
  final bool rememberMe;
  final String signature;

  _SessionRecord withSignature(String value) => _SessionRecord(
    identifier: identifier,
    accessToken: accessToken,
    accessExpiresAt: accessExpiresAt,
    refreshToken: refreshToken,
    refreshExpiresAt: refreshExpiresAt,
    rememberMe: rememberMe,
    signature: value,
  );

  AuthSession toDomain() => AuthSession(
    identifier: identifier,
    accessToken: accessToken,
    accessTokenExpiresAt: accessExpiresAt,
    refreshTokenExpiresAt: refreshExpiresAt,
    rememberMe: rememberMe,
  );
}

Future<List<int>> _derivePassword(
  String password,
  List<int> salt,
  int iterations,
) => Isolate.run(
  () => _pbkdf2Sha256(
    password: password,
    salt: salt,
    iterations: iterations,
    length: 32,
  ),
);

List<int> _pbkdf2Sha256({
  required String password,
  required List<int> salt,
  required int iterations,
  required int length,
}) {
  final key = utf8.encode(password);
  final hmac = Hmac(sha256, key);
  final output = BytesBuilder(copy: false);
  final hashLength = sha256.convert(const []).bytes.length;
  final blockCount = (length / hashLength).ceil();
  for (var block = 1; block <= blockCount; block++) {
    final suffix = ByteData(4)..setUint32(0, block, Endian.big);
    var u = hmac.convert([...salt, ...suffix.buffer.asUint8List()]).bytes;
    final combined = List<int>.from(u);
    for (var round = 1; round < iterations; round++) {
      u = hmac.convert(u).bytes;
      for (var index = 0; index < combined.length; index++) {
        combined[index] ^= u[index];
      }
    }
    output.add(combined);
  }
  return output.takeBytes().sublist(0, length);
}

List<int>? _decode(String? value) {
  if (value == null) return null;
  try {
    return base64Url.decode(base64Url.normalize(value));
  } catch (_) {
    return null;
  }
}

bool _constantTimeEquals(List<int> first, List<int> second) {
  var difference = first.length ^ second.length;
  final length = min(first.length, second.length);
  for (var index = 0; index < length; index++) {
    difference |= first[index] ^ second[index];
  }
  return difference == 0;
}
