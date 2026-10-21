import '../../../core/error/result.dart';
import 'app_settings.dart';

abstract interface class SettingsRepository {
  Future<Result<AppSettings>> load();
  Future<Result<void>> save(AppSettings settings);
}

class LoadSettings {
  const LoadSettings(this.repository);
  final SettingsRepository repository;
  Future<Result<AppSettings>> call() => repository.load();
}

class SaveSettings {
  const SaveSettings(this.repository);
  final SettingsRepository repository;
  Future<Result<void>> call(AppSettings settings) => repository.save(settings);
}
