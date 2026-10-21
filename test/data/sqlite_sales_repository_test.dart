import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/core/database/app_database.dart';
import 'package:pasora/features/sales/data/sqlite_sales_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase database;
  late SqliteSalesRepository repository;

  setUp(() async {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqliteSalesRepository(database);
    final db = await database.instance;
    await db.insert('shops', {
      'id': 's',
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
    await db.insert('categories', {
      'id': 'c',
      'shop_id': 's',
      'name': 'Baskets',
    });
    await db.insert('products', {
      'id': 'p',
      'shop_id': 's',
      'category_id': 'c',
      'name': 'Run',
      'notes': '',
    });
    await db.insert('variants', {
      'id': 'v',
      'product_id': 'p',
      'size': '40',
      'color': 'Noir',
      'stock_quantity': 10,
    });
    await db.insert('stock_entries', {
      'id': 'e',
      'shop_id': 's',
      'product_id': 'p',
      'variant_id': 'v',
      'date': '2026-01-01T00:00:00',
      'quantity': 10,
      'remaining_quantity': 10,
      'unit_purchase_price': 8000,
      'transport_cost': 5000,
      'planned_unit_sale_price': 12000,
    });
  });

  tearDown(() => database.close());

  test('vente FIFO fige le coût et diminue le stock', () async {
    final result = await repository.record(
      id: 'sale',
      shopId: 's',
      variantId: 'v',
      quantity: 2,
      unitSalePrice: 12000,
      date: DateTime(2026, 1, 2),
    );
    final sale = result.fold((f) => fail(f.message), (value) => value);
    expect(sale.frozenUnitLandedCost, 8500);
    expect(sale.profit, 7000);
    final variant = await (await database.instance).query(
      'variants',
      where: 'id = ?',
      whereArgs: ['v'],
    );
    expect(variant.single['stock_quantity'], 8);
  });

  test('annulation remet le stock et exclut la vente validée', () async {
    await repository.record(
      id: 'sale',
      shopId: 's',
      variantId: 'v',
      quantity: 2,
      unitSalePrice: 12000,
      date: DateTime(2026, 1, 2),
    );
    await repository.cancel('sale');
    final db = await database.instance;
    final variant = await db.query(
      'variants',
      where: 'id = ?',
      whereArgs: ['v'],
    );
    final entry = await db.query(
      'stock_entries',
      where: 'id = ?',
      whereArgs: ['e'],
    );
    final sales = await repository.listForPeriod(
      's',
      DateTime(2026),
      DateTime(2027),
    );
    expect(variant.single['stock_quantity'], 10);
    expect(entry.single['remaining_quantity'], 10);
    expect(
      sales.fold((f) => fail(f.message), (v) => v).single.status.name,
      'cancelled',
    );
  });

  test('refuse une vente supérieure au stock', () async {
    final result = await repository.record(
      id: 'sale',
      shopId: 's',
      variantId: 'v',
      quantity: 11,
      unitSalePrice: 12000,
      date: DateTime(2026, 1, 2),
    );
    expect(
      result.fold((f) => f.message, (_) => ''),
      contains('Stock insuffisant'),
    );
  });
}
