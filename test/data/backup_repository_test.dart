import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/core/database/app_database.dart';
import 'package:pasora/features/backup/data/google_drive_gateway.dart';
import 'package:pasora/features/backup/data/zip_backup_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  sqfliteFfiInit();

  test('crée puis restaure la base et les photos', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'pasora-backup-test-',
    );
    PathProviderPlatform.instance = _FakePathProvider(temporary.path);
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      path: p.join(temporary.path, 'pasora.sqlite'),
    );
    final db = await database.instance;
    await db.insert('shops', {
      'id': 's',
      'name': 'Originale',
      'seller_name': '',
      'whatsapp': '',
      'compensation_type': 'none',
      'percentage_rate': 0,
      'compensation_basis': 'profit',
      'is_archived': 0,
      'created_at': '2026-01-01T00:00:00',
      'updated_at': '2026-01-01T00:00:00',
    });
    final photo = File(p.join(temporary.path, 'photos', 'shoe.jpg'));
    await photo.parent.create(recursive: true);
    await photo.writeAsBytes([1, 2, 3, 4]);

    final repository = ZipBackupRepository(database, GoogleDriveGateway());
    final created = await repository.create(uploadToDrive: false);
    final record = created.fold(
      (failure) => fail(failure.message),
      (value) => value,
    );

    await db.update(
      'shops',
      {'name': 'Modifiée'},
      where: 'id = ?',
      whereArgs: ['s'],
    );
    await photo.writeAsBytes([9]);
    final restored = await repository.restore(record);
    restored.fold((failure) => fail(failure.message), (_) => null);

    final rows = await (await database.instance).query(
      'shops',
      where: 'id = ?',
      whereArgs: ['s'],
    );
    expect(rows.single['name'], 'Originale');
    expect(await photo.readAsBytes(), [1, 2, 3, 4]);

    await database.close();
    await temporary.delete(recursive: true);
  });
}
