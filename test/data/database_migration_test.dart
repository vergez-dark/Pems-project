import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/core/database/app_database.dart';
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
    await database.close();
  });
}
