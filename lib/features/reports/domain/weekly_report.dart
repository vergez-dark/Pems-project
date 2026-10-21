import '../../sales/domain/sale.dart';
import '../../shops/domain/shop.dart';

class CategoryPerformance {
  const CategoryPerformance(this.name, this.quantity, this.revenue);
  final String name;
  final int quantity;
  final int revenue;
}

class WeeklyReport {
  const WeeklyReport({
    required this.shopId,
    required this.start,
    required this.endExclusive,
    required this.salesCount,
    required this.pairsSold,
    required this.revenue,
    required this.landedCost,
    required this.profit,
    required this.remainingStock,
    required this.remainingStockValue,
    required this.sellerShare,
    required this.ownerShare,
    this.categoryPerformance = const [],
    this.sales = const [],
  });
  final String shopId;
  final DateTime start;
  final DateTime endExclusive;
  final int salesCount;
  final int pairsSold;
  final int revenue;
  final int landedCost;
  final int profit;
  final int remainingStock;
  final int remainingStockValue;
  final int sellerShare;
  final int ownerShare;
  final List<CategoryPerformance> categoryPerformance;
  final List<Sale> sales;
}

class ReportCalculator {
  const ReportCalculator();

  WeeklyReport aggregate({
    required Shop shop,
    required DateTime start,
    required DateTime endExclusive,
    required List<Sale> sales,
    int remainingStock = 0,
    int remainingStockValue = 0,
    List<CategoryPerformance> categories = const [],
  }) {
    final included = sales.where(
      (sale) =>
          sale.status == SaleStatus.validated &&
          !sale.date.isBefore(start) &&
          sale.date.isBefore(endExclusive),
    );
    final list = included.toList(growable: false);
    final revenue = list.fold<int>(0, (sum, sale) => sum + sale.revenue);
    final cost = list.fold<int>(0, (sum, sale) => sum + sale.landedCost);
    final profit = revenue - cost;
    final basis = shop.compensationBasis == CompensationBasis.revenue
        ? revenue
        : profit;
    final share = shop.compensationType == CompensationType.percentage
        ? (basis * shop.percentageRate / 100).round()
        : 0;
    return WeeklyReport(
      shopId: shop.id,
      start: start,
      endExclusive: endExclusive,
      salesCount: list.length,
      pairsSold: list.fold(0, (sum, sale) => sum + sale.quantity),
      revenue: revenue,
      landedCost: cost,
      profit: profit,
      remainingStock: remainingStock,
      remainingStockValue: remainingStockValue,
      sellerShare: share,
      ownerShare: shop.compensationBasis == CompensationBasis.profit
          ? profit - share
          : profit,
      categoryPerformance: categories,
      sales: list,
    );
  }
}
