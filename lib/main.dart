import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/debug_seeder.dart';
import 'features/backup/data/google_drive_gateway.dart';
import 'features/backup/data/zip_backup_repository.dart';
import 'features/settings/data/preferences_settings_repository.dart';

const dailyBackupTask = 'pasoraDailyBackup';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final database = AppDatabase();
    final result = await ZipBackupRepository(
      database,
      GoogleDriveGateway(allowInteractive: false),
    ).create();
    await database.close();
    return result.fold((_) => false, (_) => true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'pasora-daily-backup',
    dailyBackupTask,
    frequency: const Duration(hours: 24),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );
  if (kDebugMode && const bool.fromEnvironment('PASORA_DEMO')) {
    final database = AppDatabase();
    await DebugSeeder(database).seedIfEmpty();
    await database.close();
  }
  runApp(const ProviderScope(child: PasoraApp()));
  unawaited(_catchUpBackup());
}

Future<void> _catchUpBackup() async {
  final settingsRepository = const PreferencesSettingsRepository();
  final settingsResult = await settingsRepository.load();
  final settings = settingsResult.fold((_) => null, (value) => value);
  if (settings == null ||
      (settings.lastBackupAt != null &&
          DateTime.now().difference(settings.lastBackupAt!).inHours < 24)) {
    return;
  }
  final database = AppDatabase();
  final result = await ZipBackupRepository(
    database,
    GoogleDriveGateway(allowInteractive: false),
  ).create();
  await result.fold(
    (_) async {},
    (record) =>
        settingsRepository.save(settings.copyWith(lastBackupAt: record.date)),
  );
  await database.close();
}
