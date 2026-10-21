import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class DebugSeeder {
  const DebugSeeder(this.database);
  final AppDatabase database;

  Future<void> seedIfEmpty() async {
    final db = await database.instance;
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM shops'),
        ) ??
        0;
    if (count > 0) return;
    const date = '2026-10-20T09:00:00';
    await db.transaction((txn) async {
      await txn.insert('shops', {
        'id': 'demo-shop',
        'name': 'Boutique Akwa',
        'seller_name': 'Mireille',
        'whatsapp': '237600000000',
        'compensation_type': 'percentage',
        'percentage_rate': 20,
        'compensation_basis': 'profit',
        'is_archived': 0,
        'created_at': date,
        'updated_at': date,
      });
      await txn.insert('categories', {
        'id': 'demo-category',
        'shop_id': 'demo-shop',
        'name': 'Baskets',
      });
      await txn.insert('products', {
        'id': 'demo-product',
        'shop_id': 'demo-shop',
        'category_id': 'demo-category',
        'name': 'Urban Flex',
        'notes': 'Jeu de démonstration',
      });
      await txn.insert('variants', {
        'id': 'demo-variant',
        'product_id': 'demo-product',
        'size': '39',
        'color': 'Noir',
        'stock_quantity': 10,
      });
      await txn.insert('stock_entries', {
        'id': 'demo-entry',
        'shop_id': 'demo-shop',
        'product_id': 'demo-product',
        'variant_id': 'demo-variant',
        'date': date,
        'quantity': 10,
        'remaining_quantity': 10,
        'unit_purchase_price': 8000,
        'transport_cost': 5000,
        'planned_unit_sale_price': 12000,
      });
    });
  }
}
