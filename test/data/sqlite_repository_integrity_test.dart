import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/core/database/app_database.dart';
import 'package:pasora/features/catalog/data/sqlite_catalog_repository.dart';
import 'package:pasora/features/catalog/domain/catalog_entities.dart';
import 'package:pasora/features/inventory/data/sqlite_inventory_repository.dart';
import 'package:pasora/features/inventory/domain/stock_entry.dart';
import 'package:pasora/features/sales/data/sqlite_sales_repository.dart';
import 'package:pasora/features/shops/data/sqlite_shop_repository.dart';
import 'package:pasora/features/shops/domain/shop.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase database;
  late SqliteShopRepository shops;
  late SqliteCatalogRepository catalog;
  late SqliteInventoryRepository inventory;
  late SqliteSalesRepository sales;

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    shops = SqliteShopRepository(database);
    catalog = SqliteCatalogRepository(database);
    inventory = SqliteInventoryRepository(database);
    sales = SqliteSalesRepository(database);
  });

  tearDown(() => database.close());

  test(
    'création et modification conservent les ventes et le stock liés',
    () async {
      final date = DateTime(2026, 1, 1);
      final shop = Shop(
        id: 'shop',
        name: 'Initiale',
        createdAt: date,
        updatedAt: date,
      );
      final category = Category(
        id: 'category',
        shopId: shop.id,
        name: 'Chaussures',
      );
      final product = Product(
        id: 'product',
        shopId: shop.id,
        categoryId: category.id,
        name: 'Article',
      );
      final variant = ProductVariant(
        id: 'variant',
        productId: product.id,
        size: '40',
        color: 'Noir',
        stockQuantity: 0,
      );
      final entry = StockEntry(
        id: 'entry',
        shopId: shop.id,
        productId: product.id,
        variantId: variant.id,
        date: date,
        quantity: 5,
        remainingQuantity: 5,
        unitPurchasePrice: 1000,
        transportCost: 0,
        plannedUnitSalePrice: 1500,
      );

      (await shops.save(shop)).fold((f) => fail(f.message), (_) {});
      (await catalog.saveCategory(category))
          .fold((f) => fail(f.message), (_) {});
      (await catalog.saveProduct(
        product,
        variant,
      )).fold((f) => fail(f.message), (_) {});
      (await inventory.addEntry(entry)).fold((f) => fail(f.message), (_) {});
      (await sales.record(
        id: 'sale',
        shopId: shop.id,
        variantId: variant.id,
        quantity: 1,
        unitSalePrice: 1500,
        date: date,
      )).fold((f) => fail(f.message), (_) {});

      (await shops.save(shop.copyWith(name: 'Renommée')))
          .fold((f) => fail(f.message), (_) {});
      (await catalog.saveCategory(
        Category(id: category.id, shopId: shop.id, name: 'Baskets'),
      )).fold((f) => fail(f.message), (_) {});
      (await catalog.saveProduct(
        Product(
          id: product.id,
          shopId: shop.id,
          categoryId: category.id,
          name: 'Article corrigé',
        ),
        ProductVariant(
          id: variant.id,
          productId: product.id,
          size: '41',
          color: 'Noir',
          stockQuantity: 0,
        ),
      )).fold((f) => fail(f.message), (_) {});

      final db = await database.instance;
      expect((await db.query('shops')).single['name'], 'Renommée');
      expect((await db.query('categories')).single['name'], 'Baskets');
      expect((await db.query('products')).single['name'], 'Article corrigé');
      expect((await db.query('variants')).single['stock_quantity'], 4);
      expect(await db.query('stock_entries'), hasLength(1));
      expect(await db.query('sales'), hasLength(1));
      expect(await db.query('sale_allocations'), hasLength(1));

      (await inventory.addEntry(
        StockEntry(
          id: 'entry2',
          shopId: shop.id,
          productId: product.id,
          variantId: variant.id,
          date: date,
          quantity: 2,
          remainingQuantity: 2,
          unitPurchasePrice: 1100,
          transportCost: 0,
          plannedUnitSalePrice: 1600,
        ),
      )).fold((f) => fail(f.message), (_) {});
      (await sales.record(
        id: 'sale2',
        shopId: shop.id,
        variantId: variant.id,
        quantity: 1,
        unitSalePrice: 1600,
        date: date,
      )).fold((f) => fail(f.message), (_) {});
      expect((await db.query('variants')).single['stock_quantity'], 5);
      expect(await db.query('sales'), hasLength(2));
    },
  );
}
