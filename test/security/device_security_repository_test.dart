import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/core/error/result.dart';
import 'package:pasora/features/security/data/device_security_repository.dart';
import 'package:pasora/features/security/domain/security_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late int randomSeed;

  DeviceSecurityRepository repository() => DeviceSecurityRepository(
    clock: () => now,
    randomBytes: (length) =>
        List<int>.generate(length, (index) => (randomSeed++ + index) % 256),
    passwordIterations: 20,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 10, 21, 8);
    randomSeed = 1;
  });

  test('crée les identifiants et une session exacte de deux heures', () async {
    final repo = repository();

    final result = await repo.register(
      identifier: 'admin@pems.cm',
      password: 'MotDePasse!42',
      rememberMe: true,
    );

    final session = _success(result);
    expect(session.identifier, 'admin@pems.cm');
    expect(session.accessToken, isNotEmpty);
    expect(session.accessTokenExpiresAt, now.add(accessTokenLifetime));
    expect(session.refreshTokenExpiresAt, now.add(refreshTokenLifetime));
    expect(_success(await repo.hasCredentials()), isTrue);
  });

  test('réessaie si le canal Android des préférences est transitoirement indisponible', () async {
    final prefs = await SharedPreferences.getInstance();
    var attempts = 0;
    final repo = DeviceSecurityRepository(
      preferencesLoader: () async {
        attempts++;
        if (attempts < 3) {
          throw PlatformException(
            code: 'channel-error',
            message: 'Unable to establish connection on channel.',
          );
        }
        return prefs;
      },
      retryDelay: (_) async {},
      passwordIterations: 20,
    );

    expect(_success(await repo.hasCredentials()), isFalse);
    expect(attempts, 3);
  });

  test('refuse de se connecter avec un mot de passe incorrect', () async {
    final repo = repository();
    await repo.register(
      identifier: 'proprietaire',
      password: 'MotDePasse!42',
      rememberMe: true,
    );
    await repo.signOut();

    final result = await repo.signIn(
      identifier: 'proprietaire',
      password: 'mauvais-secret',
      rememberMe: true,
    );

    expect(result, isA<Failure<AuthSession>>());
  });

  test('restaure une session mémorisée après redémarrage', () async {
    final firstProcess = repository();
    final created = _success(
      await firstProcess.register(
        identifier: 'proprietaire',
        password: 'MotDePasse!42',
        rememberMe: true,
      ),
    );

    final restored = _success(await repository().restoreSession());

    expect(restored, isNotNull);
    expect(restored!.accessToken, created.accessToken);
    expect(restored.identifier, created.identifier);
  });

  test('ne restaure pas une session non mémorisée après redémarrage', () async {
    final firstProcess = repository();
    await firstProcess.register(
      identifier: 'proprietaire',
      password: 'MotDePasse!42',
      rememberMe: false,
    );

    expect(_success(await repository().restoreSession()), isNull);
  });

  test('fait tourner le refresh token avant expiration du jeton', () async {
    final firstProcess = repository();
    final created = _success(
      await firstProcess.register(
        identifier: 'proprietaire',
        password: 'MotDePasse!42',
        rememberMe: true,
      ),
    );
    now = now.add(const Duration(hours: 1, minutes: 56));

    final refreshed = _success(await repository().restoreSession())!;

    expect(refreshed.accessToken, isNot(created.accessToken));
    expect(refreshed.accessTokenExpiresAt, now.add(accessTokenLifetime));
    expect(refreshed.refreshTokenExpiresAt, now.add(refreshTokenLifetime));
  });

  test('refuse un refresh token expiré et détruit la session', () async {
    final firstProcess = repository();
    await firstProcess.register(
      identifier: 'proprietaire',
      password: 'MotDePasse!42',
      rememberMe: true,
    );
    now = now.add(const Duration(days: 31));
    final restarted = repository();

    expect(_success(await restarted.restoreSession()), isNull);
    expect(await restarted.refreshSession(), isA<Failure<AuthSession>>());
  });

  test('invalide une session persistée altérée', () async {
    final repo = repository();
    await repo.register(
      identifier: 'proprietaire',
      password: 'MotDePasse!42',
      rememberMe: true,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth.session.accessToken', 'jeton-modifie');

    expect(_success(await repository().restoreSession()), isNull);
  });

  test('le changement de mot de passe révoque les anciens jetons', () async {
    final repo = repository();
    final before = _success(
      await repo.register(
        identifier: 'proprietaire',
        password: 'MotDePasse!42',
        rememberMe: true,
      ),
    );

    final after = _success(
      await repo.changePassword(
        currentPassword: 'MotDePasse!42',
        newPassword: 'NouveauSecret!43',
      ),
    );

    expect(after.accessToken, isNot(before.accessToken));
    await repo.signOut();
    expect(
      await repo.signIn(
        identifier: 'proprietaire',
        password: 'MotDePasse!42',
        rememberMe: true,
      ),
      isA<Failure<AuthSession>>(),
    );
    expect(
      await repo.signIn(
        identifier: 'proprietaire',
        password: 'NouveauSecret!43',
        rememberMe: true,
      ),
      isA<Success<AuthSession>>(),
    );
  });
}

T _success<T>(Result<T> result) => result.fold(
  (failure) => throw TestFailure('Échec inattendu: ${failure.message}'),
  (value) => value,
);
