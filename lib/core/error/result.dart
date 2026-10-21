sealed class Result<T> {
  const Result();

  R fold<R>(
    R Function(AppFailure failure) onFailure,
    R Function(T value) onSuccess,
  ) {
    return switch (this) {
      Success<T>(:final value) => onSuccess(value),
      Failure<T>(:final failure) => onFailure(failure),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final AppFailure failure;
}

class AppFailure {
  const AppFailure(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
