import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/features/settings/domain/app_settings.dart';

void main() {
  test('le thème clair est le choix par défaut', () {
    expect(const AppSettings().themeMode, AppThemeMode.light);
  });

  test('le choix de thème peut être modifié', () {
    expect(
      const AppSettings().copyWith(themeMode: AppThemeMode.dark).themeMode,
      AppThemeMode.dark,
    );
  });
}
