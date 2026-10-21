import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/features/reports/domain/weekly_report.dart';
import 'package:pasora/features/sales/domain/sale.dart';
import 'package:pasora/features/shops/domain/shop.dart';

void main() {
  const calculator = ReportCalculator();
  final created = DateTime(2026);

  Shop shop({CompensationBasis basis = CompensationBasis.profit}) => Shop(
    id: 's',
    name: 'Test',
    compensationType: CompensationType.percentage,
    percentageRate: 20,
    compensationBasis: basis,
    createdAt: created,
    updatedAt: created,
  );

  Sale sale(DateTime date, {SaleStatus status = SaleStatus.validated}) => Sale(
    id: date.toIso8601String(),
    shopId: 's',
    variantId: 'v',
    date: date,
    quantity: 2,
    actualUnitSalePrice: 12000,
    frozenUnitLandedCost: 8500,
    status: status,
  );

  test('calcule bénéfice et part vendeuse sur bénéfice', () {
    final report = calculator.aggregate(
      shop: shop(),
      start: DateTime(2026, 9, 28),
      endExclusive: DateTime(2026, 10, 5),
      sales: [sale(DateTime(2026, 10, 1))],
    );
    expect(report.revenue, 24000);
    expect(report.profit, 7000);
    expect(report.sellerShare, 1400);
    expect(report.ownerShare, 5600);
  });

  test('calcule part vendeuse sur chiffre d’affaires', () {
    final report = calculator.aggregate(
      shop: shop(basis: CompensationBasis.revenue),
      start: DateTime(2026, 9, 28),
      endExclusive: DateTime(2026, 10, 5),
      sales: [sale(DateTime(2026, 10, 1))],
    );
    expect(report.sellerShare, 4800);
  });

  test('agrège une semaine à cheval sur deux mois et exclut annulations/hors période', () {
    final report = calculator.aggregate(
      shop: shop(),
      start: DateTime(2026, 9, 28),
      endExclusive: DateTime(2026, 10, 5),
      sales: [
        sale(DateTime(2026, 9, 28)),
        sale(DateTime(2026, 10, 4, 23, 59)),
        sale(DateTime(2026, 10, 5)),
        sale(DateTime(2026, 10, 2), status: SaleStatus.cancelled),
      ],
    );
    expect(report.salesCount, 2);
    expect(report.pairsSold, 4);
  });
}
