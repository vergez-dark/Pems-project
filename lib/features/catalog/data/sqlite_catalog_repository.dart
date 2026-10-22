import '../../../core/database/app_database.dart';
import '../../../core/database/database_write_failure.dart';
import '../../../core/error/result.dart';
import '../domain/catalog_entities.dart';
import '../domain/catalog_repository.dart';

class SqliteCatalogRepository implements CatalogRepository {
  const SqliteCatalogRepository(this.database);
  final AppDatabase database;

  @override
  Future<Result<List<Category>>> listCategories(String shopId) async {
    try {
      final rows = await (await database.instance).query(
        'categories',
        where: 'shop_id = ?',
        whereArgs: [shopId],
        orderBy: 'name',
      );
      return Success(
        rows
            .map(
              (r) => Category(
                id: r['id']! as String,
                shopId: r['shop_id']! as String,
                name: r['name']! as String,
              ),
            )
            .toList(),
      );
    } catch (error) {
      return Failure(AppFailure('Catégories indisponibles.', cause: error));
    }
  }

  @override
  Future<Result<void>> saveCategory(Category category) async {
    try {
      final db = await database.instance;
      await db.transaction((txn) async {
        final values = {
          'id': category.id,
          'shop_id': category.shopId,
          'name': category.name.trim(),
        };
        final updated = await txn.update(
          'categories',
          values,
          where: 'id = ?',
          whereArgs: [category.id],
        );
        if (updated == 0) await txn.insert('categories', values);
      });
      return const Success(null);
    } catch (error) {
      return Failure(
        databaseWriteFailure(
          'catalog.saveCategory',
          'Impossible d’enregistrer la catégorie.',
          error,
        ),
      );
    }
  }

  @override
  Future<Result<List<CatalogItem>>> listItems(String shopId) async {
    try {
      final rows = await (await database.instance).rawQuery(
        '''
        SELECT p.id product_id, p.shop_id, p.category_id, p.name product_name,
          p.photo_path, p.notes, v.id variant_id, v.size, v.color, v.stock_quantity,
          c.name category_name,
          COALESCE((SELECT e.planned_unit_sale_price FROM stock_entries e
            WHERE e.variant_id = v.id ORDER BY e.date DESC LIMIT 1), 0) suggested_price
        FROM products p JOIN variants v ON v.product_id = p.id
        JOIN categories c ON c.id = p.category_id
        WHERE p.shop_id = ? ORDER BY p.name COLLATE NOCASE, v.size
      ''',
        [shopId],
      );
      return Success(
        rows
            .map(
              (r) => CatalogItem(
                product: Product(
                  id: r['product_id']! as String,
                  shopId: r['shop_id']! as String,
                  categoryId: r['category_id']! as String,
                  name: r['product_name']! as String,
                  photoPath: r['photo_path'] as String?,
                  notes: r['notes']! as String,
                ),
                variant: ProductVariant(
                  id: r['variant_id']! as String,
                  productId: r['product_id']! as String,
                  size: r['size']! as String,
                  color: r['color']! as String,
                  stockQuantity: r['stock_quantity']! as int,
                ),
                categoryName: r['category_name']! as String,
                suggestedUnitSalePrice: r['suggested_price']! as int,
              ),
            )
            .toList(),
      );
    } catch (error) {
      return Failure(AppFailure('Catalogue indisponible.', cause: error));
    }
  }

  @override
  Future<Result<void>> saveProduct(
    Product product,
    ProductVariant variant,
  ) async {
    try {
      final db = await database.instance;
      await db.transaction((txn) async {
        final productValues = {
          'id': product.id,
          'shop_id': product.shopId,
          'category_id': product.categoryId,
          'name': product.name.trim(),
          'photo_path': product.photoPath,
          'notes': product.notes,
        };
        final updatedProduct = await txn.update(
          'products',
          productValues,
          where: 'id = ?',
          whereArgs: [product.id],
        );
        if (updatedProduct == 0) {
          await txn.insert('products', productValues);
        }
        final variantValues = {
          'id': variant.id,
          'product_id': variant.productId,
          'size': variant.size,
          'color': variant.color,
          'stock_quantity': variant.stockQuantity,
        };
        final updatedVariant = await txn.update(
          'variants',
          {
            'product_id': variant.productId,
            'size': variant.size,
            'color': variant.color,
          },
          where: 'id = ?',
          whereArgs: [variant.id],
        );
        if (updatedVariant == 0) {
          await txn.insert('variants', variantValues);
        }
      });
      return const Success(null);
    } catch (error) {
      return Failure(
        databaseWriteFailure(
          'catalog.saveProduct',
          'Impossible d’enregistrer l’article.',
          error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> updateProduct(
    Product product,
    ProductVariant variant,
  ) async {
    try {
      final db = await database.instance;
      await db.transaction((txn) async {
        await txn.update(
          'products',
          {
            'category_id': product.categoryId,
            'name': product.name.trim(),
            'photo_path': product.photoPath,
            'notes': product.notes,
          },
          where: 'id = ?',
          whereArgs: [product.id],
        );
        await txn.update(
          'variants',
          {'size': variant.size, 'color': variant.color},
          where: 'id = ?',
          whereArgs: [variant.id],
        );
      });
      return const Success(null);
    } catch (error) {
      return Failure(
        databaseWriteFailure(
          'catalog.updateProduct',
          'Impossible de modifier l’article.',
          error,
        ),
      );
    }
  }
}
