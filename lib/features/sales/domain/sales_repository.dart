import '../../../core/error/result.dart';
import 'sale.dart';

abstract interface class SalesRepository {
  Future<Result<Sale>> record({
    required String id,
    required String shopId,
    required String variantId,
    required int quantity,
    required int unitSalePrice,
    required DateTime date,
    PaymentMethod paymentMethod = PaymentMethod.cash,
  });
  Future<Result<void>> cancel(String saleId);
  Future<Result<List<Sale>>> listForPeriod(
    String shopId,
    DateTime start,
    DateTime endExclusive,
  );
}

class RecordSale {
  const RecordSale(this.repository);
  final SalesRepository repository;
  Future<Result<Sale>> call({
    required String id,
    required String shopId,
    required String variantId,
    required int quantity,
    required int unitSalePrice,
    required DateTime date,
    PaymentMethod paymentMethod = PaymentMethod.cash,
  }) {
    if (quantity <= 0 || unitSalePrice < 0) {
      return Future.value(
        const Failure(AppFailure('Quantité ou prix invalide.')),
      );
    }
    return repository.record(
      id: id,
      shopId: shopId,
      variantId: variantId,
      quantity: quantity,
      unitSalePrice: unitSalePrice,
      date: date,
      paymentMethod: paymentMethod,
    );
  }
}

class CancelSale {
  const CancelSale(this.repository);
  final SalesRepository repository;
  Future<Result<void>> call(String saleId) => repository.cancel(saleId);
}
