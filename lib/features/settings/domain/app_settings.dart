enum AppThemeMode { system, light, dark }

class AppSettings {
  const AppSettings({
    this.currency = 'FCFA',
    this.themeMode = AppThemeMode.system,
    this.pinEnabled = false,
    this.biometricEnabled = false,
    this.lowStockThreshold = 3,
    this.onboardingDone = false,
    this.lastBackupAt,
  });
  final String currency;
  final AppThemeMode themeMode;
  final bool pinEnabled;
  final bool biometricEnabled;
  final int lowStockThreshold;
  final bool onboardingDone;
  final DateTime? lastBackupAt;

  AppSettings copyWith({
    String? currency,
    AppThemeMode? themeMode,
    bool? pinEnabled,
    bool? biometricEnabled,
    int? lowStockThreshold,
    bool? onboardingDone,
    DateTime? lastBackupAt,
  }) => AppSettings(
    currency: currency ?? this.currency,
    themeMode: themeMode ?? this.themeMode,
    pinEnabled: pinEnabled ?? this.pinEnabled,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
  );
}
