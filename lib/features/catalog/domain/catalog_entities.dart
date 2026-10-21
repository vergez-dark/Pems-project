class Category {
  const Category({required this.id, required this.shopId, required this.name});
  final String id;
  final String shopId;
  final String name;
}

class Product {
  const Product({
    required this.id,
    required this.shopId,
    required this.categoryId,
    required this.name,
    this.photoPath,
    this.notes = '',
  });
  final String id;
  final String shopId;
  final String categoryId;
  final String name;
  final String? photoPath;
  final String notes;
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.size,
    required this.color,
    required this.stockQuantity,
  });
  final String id;
  final String productId;
  final String size;
  final String color;
  final int stockQuantity;
}

class CatalogItem {
  const CatalogItem({
    required this.product,
    required this.variant,
    required this.categoryName,
    this.suggestedUnitSalePrice = 0,
  });
  final Product product;
  final ProductVariant variant;
  final String categoryName;
  final int suggestedUnitSalePrice;
}
