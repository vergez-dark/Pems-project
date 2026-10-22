import '../../../core/database/app_database.dart';
import '../../../core/database/database_write_failure.dart';
import '../../../core/error/result.dart';
import '../domain/shop.dart';
import '../domain/shop_repository.dart';

class SqliteShopRepository implements ShopRepository {
  const SqliteShopRepository(this.database);
  final AppDatabase database;

  Shop _fromMap(Map<String, Object?> row) => Shop(
    id: row['id']! as String,
    name: row['name']! as String,
    sellerName: row['seller_name']! as String,
    whatsapp: row['whatsapp']! as String,
    photoPath: row['photo_path'] as String?,
    compensationType: CompensationType.values.byName(
      row['compensation_type']! as String,
    ),
    percentageRate: row['percentage_rate']! as int,
    compensationBasis: CompensationBasis.values.byName(
      row['compensation_basis']! as String,
    ),
    isArchived: (row['is_archived']! as int) == 1,
    createdAt: DateTime.parse(row['created_at']! as String),
    updatedAt: DateTime.parse(row['updated_at']! as String),
  );

  Map<String, Object?> _toMap(Shop shop) => {
    'id': shop.id,
    'name': shop.name,
    'seller_name': shop.sellerName,
    'whatsapp': shop.whatsapp,
    'photo_path': shop.photoPath,
    'compensation_type': shop.compensationType.name,
    'percentage_rate': shop.percentageRate,
    'compensation_basis': shop.compensationBasis.name,
    'is_archived': shop.isArchived ? 1 : 0,
    'created_at': shop.createdAt.toIso8601String(),
    'updated_at': shop.updatedAt.toIso8601String(),
  };

  @override
  Future<Result<List<Shop>>> list({bool includeArchived = false}) async {
    try {
      final db = await database.instance;
      final rows = await db.query(
        'shops',
        where: includeArchived ? null : 'is_archived = 0',
        orderBy: 'name COLLATE NOCASE',
      );
      return Success(rows.map(_fromMap).toList(growable: false));
    } catch (error) {
      return Failure(
        AppFailure('Impossible de charger les boutiques.', cause: error),
      );
    }
  }

  @override
  Future<Result<Shop?>> getById(String id) async {
    try {
      final rows = await (await database.instance).query(
        'shops',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return Success(rows.isEmpty ? null : _fromMap(rows.first));
    } catch (error) {
      return Failure(AppFailure('Boutique introuvable.', cause: error));
    }
  }

  @override
  Future<Result<void>> save(Shop shop) async {
    try {
      final db = await database.instance;
      await db.transaction((txn) async {
        final values = _toMap(shop);
        final updated = await txn.update(
          'shops',
          values,
          where: 'id = ?',
          whereArgs: [shop.id],
        );
        if (updated == 0) {
          await txn.insert('shops', values);
        }
      });
      return const Success(null);
    } catch (error) {
      return Failure(
        databaseWriteFailure('shop.save', 'Enregistrement impossible.', error),
      );
    }
  }

  @override
  Future<Result<void>> archive(String id, bool archived) async {
    try {
      await (await database.instance).update(
        'shops',
        {
          'is_archived': archived ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return const Success(null);
    } catch (error) {
      return Failure(
        databaseWriteFailure('shop.archive', 'Archivage impossible.', error),
      );
    }
  }
}
