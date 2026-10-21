import '../../../core/error/result.dart';

const accessTokenLifetime = Duration(hours: 2);
const refreshTokenLifetime = Duration(days: 30);
const refreshTokenLeeway = Duration(minutes: 5);

class AuthSession {
  const AuthSession({
    required this.identifier,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.rememberMe,
  });

  final String identifier;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;
  final bool rememberMe;

  bool needsRefresh(DateTime now) =>
      !accessTokenExpiresAt.isAfter(now.add(refreshTokenLeeway));
}

abstract interface class SecurityRepository {
  Future<Result<bool>> hasCredentials();
  Future<Result<String?>> savedIdentifier();
  Future<Result<AuthSession>> register({
    required String identifier,
    required String password,
    required bool rememberMe,
  });
  Future<Result<AuthSession>> signIn({
    required String identifier,
    required String password,
    required bool rememberMe,
  });
  Future<Result<AuthSession?>> restoreSession();
  Future<Result<AuthSession>> refreshSession();
  Future<Result<void>> signOut();
  Future<Result<AuthSession>> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<Result<bool>> authenticateBiometrics();
  Future<Result<AuthSession>> signInWithBiometrics({required bool rememberMe});
}

class AuthenticateOwner {
  const AuthenticateOwner(this.repository);
  final SecurityRepository repository;
  Future<Result<bool>> call() => repository.authenticateBiometrics();
}
