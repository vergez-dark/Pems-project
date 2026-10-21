import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/result.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

class PreferencesSettingsRepository implements SettingsRepository {
  const PreferencesSettingsRepository();

  @override
  Future<Result<AppSettings>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString('lastBackupAt');
      final savedTheme = prefs.getString('themeMode');
      // Les anciennes installations avaient « système » par défaut. On les
      // bascule une fois vers clair ; un choix ultérieur reste explicite.
      final isLegacyTheme =
          savedTheme == AppThemeMode.system.name &&
          !prefs.containsKey('themeModeExplicit');
      return Success(
        AppSettings(
          currency: prefs.getString('currency') ?? 'FCFA',
          themeMode: savedTheme == null || isLegacyTheme
              ? AppThemeMode.light
              : AppThemeMode.values.byName(savedTheme),
          biometricEnabled: prefs.getBool('biometricEnabled') ?? false,
          lowStockThreshold: prefs.getInt('lowStockThreshold') ?? 3,
          onboardingDone: prefs.getBool('onboardingDone') ?? false,
          lastBackupAt: last == null ? null : DateTime.tryParse(last),
        ),
      );
    } catch (error) {
      return Failure(AppFailure('Paramètres indisponibles.', cause: error));
    }
  }

  @override
  Future<Result<void>> save(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString('currency', settings.currency),
        prefs.setString('themeMode', settings.themeMode.name),
        prefs.setBool('themeModeExplicit', true),
        prefs.setBool('biometricEnabled', settings.biometricEnabled),
        prefs.setInt('lowStockThreshold', settings.lowStockThreshold),
        prefs.setBool('onboardingDone', settings.onboardingDone),
        if (settings.lastBackupAt != null)
          prefs.setString(
            'lastBackupAt',
            settings.lastBackupAt!.toIso8601String(),
          ),
      ]);
      return const Success(null);
    } catch (error) {
      return Failure(
        AppFailure('Enregistrement des paramètres impossible.', cause: error),
      );
    }
  }
}
