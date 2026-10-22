import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'fermer la connexion de sauvegarde ne ferme pas celle de l’interface',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pems-db-isolation-',
      );
      final path = p.join(directory.path, 'pasora.sqlite');
      final interface = AppDatabase(factory: databaseFactoryFfi, path: path);
      final backup = AppDatabase(factory: databaseFactoryFfi, path: path);
      try {
        final interfaceDb = await interface.instance;
        await backup.instance;
        await backup.close();

        await interfaceDb.insert('shops', {
          'id': 'shop-after-backup',
          'name': 'Boutique',
          'seller_name': '',
          'whatsapp': '',
          'compensation_type': 'none',
          'percentage_rate': 0,
          'compensation_basis': 'profit',
          'is_archived': 0,
          'created_at': '2026-01-01T00:00:00',
          'updated_at': '2026-01-01T00:00:00',
        });
        expect(await interfaceDb.query('shops'), hasLength(1));
      } finally {
        await backup.close();
        await interface.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
