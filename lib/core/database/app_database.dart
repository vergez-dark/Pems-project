import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? path})
    : _factory = factory ?? databaseFactory,
      _customPath = path;

  static const schemaVersion = 3;
  final DatabaseFactory _factory;
  final String? _customPath;
  Database? _database;

  Future<String> get path async {
    if (_customPath != null) return _customPath;
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, 'pasora.sqlite');
  }

  Future<Database> get instance async => _database ??= await _open();

  Future<Database> _open() async => _factory.openDatabase(
    await path,
    options: OpenDatabaseOptions(
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => _migrate(db, 0, version),
      onUpgrade: _migrate,
    ),
  );

  Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) {
      await db.execute(
        '''CREATE TABLE shops(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, seller_name TEXT NOT NULL DEFAULT '',
        whatsapp TEXT NOT NULL DEFAULT '', compensation_type TEXT NOT NULL,
        percentage_rate INTEGER NOT NULL DEFAULT 0, compensation_basis TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
      );
      await db.execute('''CREATE TABLE categories(
        id TEXT PRIMARY KEY, shop_id TEXT NOT NULL REFERENCES shops(id), name TEXT NOT NULL,
        UNIQUE(shop_id, name))''');
      await db.execute('''CREATE TABLE products(
        id TEXT PRIMARY KEY, shop_id TEXT NOT NULL REFERENCES shops(id),
        category_id TEXT NOT NULL REFERENCES categories(id), name TEXT NOT NULL,
        photo_path TEXT, notes TEXT NOT NULL DEFAULT '')''');
      await db.execute('''CREATE TABLE variants(
        id TEXT PRIMARY KEY, product_id TEXT NOT NULL REFERENCES products(id),
        size TEXT NOT NULL, color TEXT NOT NULL, stock_quantity INTEGER NOT NULL DEFAULT 0,
        UNIQUE(product_id, size, color))''');
      await db.execute('''CREATE TABLE stock_entries(
        id TEXT PRIMARY KEY, shop_id TEXT NOT NULL REFERENCES shops(id),
        product_id TEXT NOT NULL REFERENCES products(id), variant_id TEXT NOT NULL REFERENCES variants(id),
        date TEXT NOT NULL, quantity INTEGER NOT NULL, remaining_quantity INTEGER NOT NULL,
        unit_purchase_price INTEGER NOT NULL, transport_cost INTEGER NOT NULL,
        planned_unit_sale_price INTEGER NOT NULL)''');
      await db.execute('''CREATE TABLE sales(
        id TEXT PRIMARY KEY, shop_id TEXT NOT NULL REFERENCES shops(id),
        variant_id TEXT NOT NULL REFERENCES variants(id), date TEXT NOT NULL,
        quantity INTEGER NOT NULL, actual_unit_sale_price INTEGER NOT NULL,
        frozen_unit_landed_cost INTEGER NOT NULL, status TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE sale_allocations(
        sale_id TEXT NOT NULL REFERENCES sales(id), entry_id TEXT NOT NULL REFERENCES stock_entries(id),
        quantity INTEGER NOT NULL, unit_landed_cost INTEGER NOT NULL,
        PRIMARY KEY(sale_id, entry_id))''');
      await db.execute('''CREATE TABLE backup_records(
        id TEXT PRIMARY KEY, date TEXT NOT NULL, size INTEGER NOT NULL,
        drive_file_id TEXT, status TEXT NOT NULL, local_path TEXT)''');
      await db.execute('''CREATE TABLE settings(
        key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
    }
    if (oldVersion < 2) {
      await db.execute(
        'CREATE INDEX idx_categories_shop ON categories(shop_id)',
      );
      await db.execute('CREATE INDEX idx_products_shop ON products(shop_id)');
      await db.execute(
        'CREATE INDEX idx_variants_product ON variants(product_id)',
      );
      await db.execute(
        'CREATE INDEX idx_entries_variant_date ON stock_entries(variant_id, date)',
      );
      await db.execute(
        'CREATE INDEX idx_sales_shop_date ON sales(shop_id, date)',
      );
      await db.execute('CREATE INDEX idx_sales_variant ON sales(variant_id)');
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE sales ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'cash'",
      );
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
