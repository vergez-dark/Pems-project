import '../../../core/error/result.dart';
import 'stock_entry.dart';

abstract interface class InventoryRepository {
  Future<Result<void>> addEntry(StockEntry entry);
  Future<Result<List<StockEntry>>> entriesForVariant(String variantId);
  Future<Result<int>> availableStock(String variantId);
}

class AddStockEntry {
  const AddStockEntry(this.repository);
  final InventoryRepository repository;
  Future<Result<void>> call(StockEntry entry) {
    if (entry.quantity <= 0) {
      return Future.value(
        const Failure(AppFailure('La quantité doit être positive.')),
      );
    }
    return repository.addEntry(entry);
  }
}
