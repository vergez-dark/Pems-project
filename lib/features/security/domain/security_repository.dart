import '../../../core/error/result.dart';

abstract interface class SecurityRepository {
  Future<Result<bool>> authenticate();
  Future<Result<void>> setPin(String pin);
  Future<Result<bool>> verifyPin(String pin);
}

class AuthenticateOwner {
  const AuthenticateOwner(this.repository);
  final SecurityRepository repository;
  Future<Result<bool>> call() => repository.authenticate();
}

class SetPin {
  const SetPin(this.repository);
  final SecurityRepository repository;
  Future<Result<void>> call(String pin) => repository.setPin(pin);
}

class VerifyPin {
  const VerifyPin(this.repository);
  final SecurityRepository repository;
  Future<Result<bool>> call(String pin) => repository.verifyPin(pin);
}
