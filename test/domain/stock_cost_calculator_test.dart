import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/features/inventory/domain/stock_entry.dart';

void main() {
  const calculator = StockCostCalculator();

  test('10 paires à 8000 + 5000 transport coûtent 8500 chacune', () {
    expect(
      calculator.unitLandedCost(
        quantity: 10,
        unitPurchasePrice: 8000,
        transportCost: 5000,
      ),
      8500,
    );
    expect(
      calculator.plannedProfit(
        quantity: 10,
        unitPurchasePrice: 8000,
        transportCost: 5000,
        unitSalePrice: 12000,
      ),
      35000,
    );
  });

  test('refuse une quantité nulle', () {
    expect(
      () => calculator.unitTransportCost(quantity: 0, transportCost: 5000),
      throwsArgumentError,
    );
  });
}
