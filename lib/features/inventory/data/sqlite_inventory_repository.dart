import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_write_failure.dart';
import '../../../core/error/result.dart';
import '../domain/inventory_repository.dart';
import '../domain/stock_entry.dart';

class SqliteInventoryRepository implements InventoryRepository {
  const SqliteInventoryRepository(this.database);
  final AppDatabase database;

  @override
  Future<Result<void>> addEntry(StockEntry entry) async {
    try {
      final db = await database.instance;
      await db.transaction((txn) async {
        await txn.insert('stock_entries', {
          'id': entry.id,
          'shop_id': entry.shopId,
          'product_id': entry.productId,
          'variant_id': entry.variantId,
          'date': entry.date.toIso8601String(),
          'quantity': entry.quantity,
          'remaining_quantity': entry.quantity,
          'unit_purchase_price': entry.unitPurchasePrice,
          'transport_cost': entry.transportCost,
          'planned_unit_sale_price': entry.plannedUnitSalePrice,
        }, conflictAlgorithm: ConflictAlgorithm.abort);
        await txn.rawUpdate(
          'UPDATE variants SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [entry.quantity, entry.variantId],
        );
      });
      return const Success(null);
    } catch (error) {
      return Failure(
        databaseWriteFailure(
          'inventory.addEntry',
          'Entrée de stock impossible.',
          error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> updateEntry(StockEntry entry) async {
    try {
      final db = await database.instance;
      await db.transaction((txn) async {
        final rows = await txn.query(
          'stock_entries',
          columns: ['quantity', 'remaining_quantity'],
          where: 'id = ?',
          whereArgs: [entry.id],
          limit: 1,
        );
        if (rows.isEmpty) throw StateError('Entrée de stock introuvable.');

        final oldQuantity = rows.first['quantity']! as int;
        final oldRemaining = rows.first['remaining_quantity']! as int;
        final quantityAlreadySold = oldQuantity - oldRemaining;
        if (entry.quantity < quantityAlreadySold) {
          throw StateError(
            'La quantité est inférieure aux paires déjà vendues.',
          );
        }
        final newRemaining = entry.quantity - quantityAlreadySold;
        await txn.update(
          'stock_entries',
          {
            'quantity': entry.quantity,
            'remaining_quantity': newRemaining,
            'unit_purchase_price': entry.unitPurchasePrice,
            'transport_cost': entry.transportCost,
            'planned_unit_sale_price': entry.plannedUnitSalePrice,
          },
          where: 'id = ?',
          whereArgs: [entry.id],
        );
        await txn.rawUpdate(
          'UPDATE variants SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [newRemaining - oldRemaining, entry.variantId],
        );
      });
      return const Success(null);
    } catch (error) {
      return Failure(
        databaseWriteFailure(
          'inventory.updateEntry',
          'Impossible de modifier le stock initial.',
          error,
        ),
      );
    }
  }

  StockEntry _map(Map<String, Object?> row) => StockEntry(
    id: row['id']! as String,
    shopId: row['shop_id']! as String,
    productId: row['product_id']! as String,
    variantId: row['variant_id']! as String,
    date: DateTime.parse(row['date']! as String),
    quantity: row['quantity']! as int,
    remainingQuantity: row['remaining_quantity']! as int,
    unitPurchasePrice: row['unit_purchase_price']! as int,
    transportCost: row['transport_cost']! as int,
    plannedUnitSalePrice: row['planned_unit_sale_price']! as int,
  );

  @override
  Future<Result<List<StockEntry>>> entriesForVariant(String variantId) async {
    try {
      final rows = await (await database.instance).query(
        'stock_entries',
        where: 'variant_id = ?',
        whereArgs: [variantId],
        orderBy: 'date ASC',
      );
      return Success(rows.map(_map).toList());
    } catch (error) {
      return Failure(
        AppFailure('Historique du stock indisponible.', cause: error),
      );
    }
  }

  @override
  Future<Result<int>> availableStock(String variantId) async {
    try {
      final rows = await (await database.instance).query(
        'variants',
        columns: ['stock_quantity'],
        where: 'id = ?',
        whereArgs: [variantId],
      );
      return Success(rows.isEmpty ? 0 : rows.first['stock_quantity']! as int);
    } catch (error) {
      return Failure(AppFailure('Stock indisponible.', cause: error));
    }
  }
}
