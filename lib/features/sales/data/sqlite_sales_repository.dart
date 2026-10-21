import '../../../core/database/app_database.dart';
import '../../../core/error/result.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';

class SqliteSalesRepository implements SalesRepository {
  const SqliteSalesRepository(this.database);
  final AppDatabase database;

  @override
  Future<Result<Sale>> record({
    required String id,
    required String shopId,
    required String variantId,
    required int quantity,
    required int unitSalePrice,
    required DateTime date,
    PaymentMethod paymentMethod = PaymentMethod.cash,
  }) async {
    try {
      final db = await database.instance;
      final sale = await db.transaction((txn) async {
        final variants = await txn.query(
          'variants',
          where: 'id = ?',
          whereArgs: [variantId],
          limit: 1,
        );
        if (variants.isEmpty ||
            (variants.first['stock_quantity']! as int) < quantity) {
          throw StateError('Stock insuffisant pour cette vente.');
        }
        final lots = await txn.query(
          'stock_entries',
          where: 'variant_id = ? AND remaining_quantity > 0',
          whereArgs: [variantId],
          orderBy: 'date ASC, id ASC',
        );
        var toAllocate = quantity;
        var totalCost = 0;
        final allocations = <SaleLine>[];
        for (final lot in lots) {
          if (toAllocate == 0) break;
          final available = lot['remaining_quantity']! as int;
          final taken = available < toAllocate ? available : toAllocate;
          final lotQuantity = lot['quantity']! as int;
          final unitCost =
              (lot['unit_purchase_price']! as int) +
              (lot['transport_cost']! as int) ~/ lotQuantity;
          totalCost += taken * unitCost;
          allocations.add(
            SaleLine(
              entryId: lot['id']! as String,
              quantity: taken,
              unitLandedCost: unitCost,
            ),
          );
          await txn.update(
            'stock_entries',
            {'remaining_quantity': available - taken},
            where: 'id = ?',
            whereArgs: [lot['id']],
          );
          toAllocate -= taken;
        }
        if (toAllocate != 0) throw StateError('Lots de stock incohérents.');
        final frozenCost = totalCost ~/ quantity;
        final created = Sale(
          id: id,
          shopId: shopId,
          variantId: variantId,
          date: date,
          quantity: quantity,
          actualUnitSalePrice: unitSalePrice,
          frozenUnitLandedCost: frozenCost,
          paymentMethod: paymentMethod,
        );
        await txn.insert('sales', {
          'id': id,
          'shop_id': shopId,
          'variant_id': variantId,
          'date': date.toIso8601String(),
          'quantity': quantity,
          'actual_unit_sale_price': unitSalePrice,
          'frozen_unit_landed_cost': frozenCost,
          'status': SaleStatus.validated.name,
          'payment_method': paymentMethod.name,
        });
        for (final allocation in allocations) {
          await txn.insert('sale_allocations', {
            'sale_id': id,
            'entry_id': allocation.entryId,
            'quantity': allocation.quantity,
            'unit_landed_cost': allocation.unitLandedCost,
          });
        }
        await txn.rawUpdate(
          'UPDATE variants SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [quantity, variantId],
        );
        return created;
      });
      return Success(sale);
    } catch (error) {
      final message = error is StateError ? error.message : 'Vente impossible.';
      return Failure(AppFailure(message, cause: error));
    }
  }

  @override
  Future<Result<void>> cancel(String saleId) async {
    try {
      final db = await database.instance;
      await db.transaction((txn) async {
        final rows = await txn.query(
          'sales',
          where: 'id = ?',
          whereArgs: [saleId],
          limit: 1,
        );
        if (rows.isEmpty) throw StateError('Vente introuvable.');
        final row = rows.first;
        if (row['status'] == SaleStatus.cancelled.name) return;
        final allocations = await txn.query(
          'sale_allocations',
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );
        for (final allocation in allocations) {
          await txn.rawUpdate(
            'UPDATE stock_entries SET remaining_quantity = remaining_quantity + ? WHERE id = ?',
            [allocation['quantity'], allocation['entry_id']],
          );
        }
        await txn.rawUpdate(
          'UPDATE variants SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [row['quantity'], row['variant_id']],
        );
        await txn.update(
          'sales',
          {'status': SaleStatus.cancelled.name},
          where: 'id = ?',
          whereArgs: [saleId],
        );
      });
      return const Success(null);
    } catch (error) {
      return Failure(AppFailure('Annulation impossible.', cause: error));
    }
  }

  Sale _map(Map<String, Object?> row) => Sale(
    id: row['id']! as String,
    shopId: row['shop_id']! as String,
    variantId: row['variant_id']! as String,
    date: DateTime.parse(row['date']! as String),
    quantity: row['quantity']! as int,
    actualUnitSalePrice: row['actual_unit_sale_price']! as int,
    frozenUnitLandedCost: row['frozen_unit_landed_cost']! as int,
    status: SaleStatus.values.byName(row['status']! as String),
    paymentMethod: PaymentMethod.values.byName(
      (row['payment_method'] as String?) ?? PaymentMethod.cash.name,
    ),
  );

  @override
  Future<Result<List<Sale>>> listForPeriod(
    String shopId,
    DateTime start,
    DateTime endExclusive,
  ) async {
    try {
      final rows = await (await database.instance).query(
        'sales',
        where: 'shop_id = ? AND date >= ? AND date < ?',
        whereArgs: [
          shopId,
          start.toIso8601String(),
          endExclusive.toIso8601String(),
        ],
        orderBy: 'date DESC',
      );
      return Success(rows.map(_map).toList());
    } catch (error) {
      return Failure(AppFailure('Ventes indisponibles.', cause: error));
    }
  }
}
