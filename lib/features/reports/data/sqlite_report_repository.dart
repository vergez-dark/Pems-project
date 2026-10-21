import '../../../core/database/app_database.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/date_range.dart';
import '../../sales/domain/sales_repository.dart';
import '../../shops/domain/shop_repository.dart';
import '../domain/report_repository.dart';
import '../domain/weekly_report.dart';

class SqliteReportRepository implements ReportRepository {
  const SqliteReportRepository({
    required this.database,
    required this.shops,
    required this.sales,
    this.calculator = const ReportCalculator(),
  });
  final AppDatabase database;
  final ShopRepository shops;
  final SalesRepository sales;
  final ReportCalculator calculator;

  @override
  Future<Result<WeeklyReport>> weekly(String shopId, DateTime anchor) async {
    final week = WeekRange.from(anchor);
    final shopResult = await shops.getById(shopId);
    final shop = shopResult.fold((_) => null, (value) => value);
    if (shop == null) return const Failure(AppFailure('Boutique introuvable.'));
    final salesResult = await sales.listForPeriod(
      shopId,
      week.start,
      week.endExclusive,
    );
    final periodSales = salesResult.fold((_) => null, (value) => value);
    if (periodSales == null) {
      return const Failure(AppFailure('Rapport indisponible.'));
    }
    try {
      final db = await database.instance;
      final totals = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(v.stock_quantity), 0) stock,
          COALESCE(SUM(v.stock_quantity * (e.unit_purchase_price + e.transport_cost / e.quantity)), 0) value
        FROM variants v JOIN products p ON p.id = v.product_id
        LEFT JOIN stock_entries e ON e.id = (
          SELECT e2.id FROM stock_entries e2 WHERE e2.variant_id = v.id
          ORDER BY e2.date DESC LIMIT 1)
        WHERE p.shop_id = ?
      ''',
        [shopId],
      );
      final categoryRows = await db.rawQuery(
        '''
        SELECT c.name, COALESCE(SUM(s.quantity), 0) quantity,
          COALESCE(SUM(s.quantity * s.actual_unit_sale_price), 0) revenue
        FROM categories c
        LEFT JOIN products p ON p.category_id = c.id
        LEFT JOIN variants v ON v.product_id = p.id
        LEFT JOIN sales s ON s.variant_id = v.id AND s.status = 'validated'
          AND s.date >= ? AND s.date < ?
        WHERE c.shop_id = ? GROUP BY c.id ORDER BY revenue DESC
      ''',
        [
          week.start.toIso8601String(),
          week.endExclusive.toIso8601String(),
          shopId,
        ],
      );
      final total = totals.first;
      return Success(
        calculator.aggregate(
          shop: shop,
          start: week.start,
          endExclusive: week.endExclusive,
          sales: periodSales,
          remainingStock: (total['stock'] as num).toInt(),
          remainingStockValue: (total['value'] as num).toInt(),
          categories: categoryRows
              .map(
                (row) => CategoryPerformance(
                  row['name']! as String,
                  (row['quantity'] as num).toInt(),
                  (row['revenue'] as num).toInt(),
                ),
              )
              .toList(),
        ),
      );
    } catch (error) {
      return Failure(AppFailure('Calcul du rapport impossible.', cause: error));
    }
  }
}
