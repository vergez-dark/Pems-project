/// Tracks an Android/iOS activity deliberately opened by the app, such as the
/// system camera or photo picker. It must not be treated as the user leaving
/// PeMS Store while a secure form is still in progress.
class ExternalActivityGuard {
  int _activeCount = 0;
  void Function()? onIdle;

  bool get isActive => _activeCount > 0;

  Future<T> run<T>(Future<T> Function() action) async {
    _activeCount++;
    try {
      return await action();
    } finally {
      _activeCount--;
      if (!isActive) onIdle?.call();
    }
  }
}
