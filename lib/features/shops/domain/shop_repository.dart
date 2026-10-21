import '../../../core/error/result.dart';
import 'shop.dart';

abstract interface class ShopRepository {
  Future<Result<List<Shop>>> list({bool includeArchived = false});
  Future<Result<Shop?>> getById(String id);
  Future<Result<void>> save(Shop shop);
  Future<Result<void>> archive(String id, bool archived);
}

class ListShops {
  const ListShops(this.repository);
  final ShopRepository repository;
  Future<Result<List<Shop>>> call({bool includeArchived = false}) =>
      repository.list(includeArchived: includeArchived);
}

class SaveShop {
  const SaveShop(this.repository);
  final ShopRepository repository;
  Future<Result<void>> call(Shop shop) {
    if (shop.name.trim().isEmpty) {
      return Future.value(const Failure(AppFailure('Le nom est obligatoire.')));
    }
    if (shop.percentageRate < 0 || shop.percentageRate > 100) {
      return Future.value(
        const Failure(AppFailure('Le taux doit être entre 0 et 100.')),
      );
    }
    return repository.save(shop);
  }
}

class ArchiveShop {
  const ArchiveShop(this.repository);
  final ShopRepository repository;
  Future<Result<void>> call(String id, bool archived) =>
      repository.archive(id, archived);
}
