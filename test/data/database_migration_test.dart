import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test('crée le schéma courant et ses index', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final db = await database.instance;
    expect(await db.getVersion(), AppDatabase.schemaVersion);
    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index'",
    );
    expect(indexes.map((row) => row['name']), contains('idx_sales_shop_date'));
    final shopColumns = await db.rawQuery('PRAGMA table_info(shops)');
    expect(shopColumns.map((row) => row['name']), contains('photo_path'));
    await database.close();
  });

  test('partage la même ouverture lors de lectures simultanées', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pasora-concurrent-open-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      path: p.join(directory.path, 'concurrent.sqlite'),
    );
    final connections = await Future.wait(
      List.generate(8, (_) => database.instance),
    );
    expect(connections.every((db) => identical(db, connections.first)), isTrue);
    await database.close();
  });

  test('ajoute la photo boutique lors du passage du schéma 3 à 4', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pasora-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'legacy.sqlite');
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) => db.execute('''CREATE TABLE shops(
          id TEXT PRIMARY KEY, name TEXT NOT NULL,
          seller_name TEXT NOT NULL DEFAULT '', whatsapp TEXT NOT NULL DEFAULT '',
          compensation_type TEXT NOT NULL, percentage_rate INTEGER NOT NULL DEFAULT 0,
          compensation_basis TEXT NOT NULL, is_archived INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL)'''),
      ),
    );
    await legacy.close();

    final database = AppDatabase(factory: databaseFactoryFfi, path: path);
    final upgraded = await database.instance;
    final columns = await upgraded.rawQuery('PRAGMA table_info(shops)');

    expect(await upgraded.getVersion(), 4);
    expect(columns.map((row) => row['name']), contains('photo_path'));
    await database.close();
  });
}
