import '../../../core/error/result.dart';
import 'catalog_entities.dart';

abstract interface class CatalogRepository {
  Future<Result<List<Category>>> listCategories(String shopId);
  Future<Result<void>> saveCategory(Category category);
  Future<Result<List<CatalogItem>>> listItems(String shopId);
  Future<Result<void>> saveProduct(Product product, ProductVariant variant);
  Future<Result<void>> updateProduct(Product product, ProductVariant variant);
}

class ListCategories {
  const ListCategories(this.repository);
  final CatalogRepository repository;
  Future<Result<List<Category>>> call(String shopId) =>
      repository.listCategories(shopId);
}

class ListCatalogItems {
  const ListCatalogItems(this.repository);
  final CatalogRepository repository;
  Future<Result<List<CatalogItem>>> call(String shopId) =>
      repository.listItems(shopId);
}

class SaveCategory {
  const SaveCategory(this.repository);
  final CatalogRepository repository;
  Future<Result<void>> call(Category category) =>
      repository.saveCategory(category);
}

class SaveProduct {
  const SaveProduct(this.repository);
  final CatalogRepository repository;
  Future<Result<void>> call(Product product, ProductVariant variant) =>
      repository.saveProduct(product, variant);
}

class UpdateProduct {
  const UpdateProduct(this.repository);
  final CatalogRepository repository;
  Future<Result<void>> call(Product product, ProductVariant variant) =>
      repository.updateProduct(product, variant);
}
