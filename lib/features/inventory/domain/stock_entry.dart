class StockEntry {
  const StockEntry({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.variantId,
    required this.date,
    required this.quantity,
    required this.remainingQuantity,
    required this.unitPurchasePrice,
    required this.transportCost,
    required this.plannedUnitSalePrice,
  });
  final String id;
  final String shopId;
  final String productId;
  final String variantId;
  final DateTime date;
  final int quantity;
  final int remainingQuantity;
  final int unitPurchasePrice;
  final int transportCost;
  final int plannedUnitSalePrice;

  int get unitTransportCost => quantity == 0 ? 0 : transportCost ~/ quantity;
  int get unitLandedCost => unitPurchasePrice + unitTransportCost;
  int get plannedUnitProfit => plannedUnitSalePrice - unitLandedCost;
}

class StockCostCalculator {
  const StockCostCalculator();

  int unitTransportCost({required int quantity, required int transportCost}) {
    if (quantity <= 0) throw ArgumentError.value(quantity, 'quantity');
    return transportCost ~/ quantity;
  }

  int unitLandedCost({
    required int quantity,
    required int unitPurchasePrice,
    required int transportCost,
  }) =>
      unitPurchasePrice +
      unitTransportCost(quantity: quantity, transportCost: transportCost);

  int plannedProfit({
    required int quantity,
    required int unitPurchasePrice,
    required int transportCost,
    required int unitSalePrice,
  }) =>
      (unitSalePrice -
          unitLandedCost(
            quantity: quantity,
            unitPurchasePrice: unitPurchasePrice,
            transportCost: transportCost,
          )) *
      quantity;
}
