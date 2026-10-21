enum SaleStatus { validated, cancelled }

enum PaymentMethod { cash, mobileMoney, card }

class Sale {
  const Sale({
    required this.id,
    required this.shopId,
    required this.variantId,
    required this.date,
    required this.quantity,
    required this.actualUnitSalePrice,
    required this.frozenUnitLandedCost,
    this.status = SaleStatus.validated,
    this.paymentMethod = PaymentMethod.cash,
  });
  final String id;
  final String shopId;
  final String variantId;
  final DateTime date;
  final int quantity;
  final int actualUnitSalePrice;
  final int frozenUnitLandedCost;
  final SaleStatus status;
  final PaymentMethod paymentMethod;

  int get revenue => actualUnitSalePrice * quantity;
  int get landedCost => frozenUnitLandedCost * quantity;
  int get profit => (actualUnitSalePrice - frozenUnitLandedCost) * quantity;
}

class SaleLine {
  const SaleLine({
    required this.entryId,
    required this.quantity,
    required this.unitLandedCost,
  });
  final String entryId;
  final int quantity;
  final int unitLandedCost;
}
