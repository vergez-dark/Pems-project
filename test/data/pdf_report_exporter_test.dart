import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pasora/features/reports/data/pdf_report_exporter.dart';
import 'package:pasora/features/reports/domain/weekly_report.dart';
import 'package:pasora/features/sales/domain/sale.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TemporaryPathProvider extends PathProviderPlatform {
  _TemporaryPathProvider(this.path);
  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test(
    'exporte un rapport multipage et un rapport vendeuse lisibles',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'pems-report-test-',
      );
      final previousProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TemporaryPathProvider(temporary.path);
      addTearDown(() async {
        PathProviderPlatform.instance = previousProvider;
        await temporary.delete(recursive: true);
      });

      final sales = List.generate(
        60,
        (index) => Sale(
          id: 'sale-$index',
          shopId: 'shop',
          variantId: 'variant',
          date: DateTime(2026, 10, 22),
          quantity: 2,
          actualUnitSalePrice: 12500,
          frozenUnitLandedCost: 8700,
        ),
      );
      final report = WeeklyReport(
        shopId: 'shop',
        start: DateTime(2026, 10, 19),
        endExclusive: DateTime(2026, 10, 26),
        salesCount: sales.length,
        pairsSold: sales.length * 2,
        revenue: 1500000,
        landedCost: 1044000,
        profit: 456000,
        remainingStock: 28,
        remainingStockValue: 243600,
        sellerShare: 91200,
        ownerShare: 364800,
        sales: sales,
      );
      const exporter = PdfReportExporter();

      final ownerResult = await exporter.exportPdf(report, 'Boutique Vergèze');
      final ownerPath = ownerResult.fold(
        (failure) => fail('${failure.message}: ${failure.cause}'),
        (path) => path,
      );
      expect(await File(ownerPath).length(), greaterThan(5000));

      const qaOutput = String.fromEnvironment('PDF_QA_OUTPUT');
      if (qaOutput.isNotEmpty) await File(ownerPath).copy(qaOutput);

      final sellerResult = await exporter.exportPdf(
        report,
        'Boutique d’Été',
        sellerOnly: true,
      );
      final sellerPath = sellerResult.fold(
        (failure) => fail('${failure.message}: ${failure.cause}'),
        (path) => path,
      );
      expect(await File(sellerPath).length(), greaterThan(5000));
      const sellerQaOutput = String.fromEnvironment('PDF_QA_SELLER_OUTPUT');
      if (sellerQaOutput.isNotEmpty) {
        await File(sellerPath).copy(sellerQaOutput);
      }

      final empty = WeeklyReport(
        shopId: 'shop',
        start: DateTime(2026, 10, 19),
        endExclusive: DateTime(2026, 10, 26),
        salesCount: 0,
        pairsSold: 0,
        revenue: 0,
        landedCost: 0,
        profit: 0,
        remainingStock: 0,
        remainingStockValue: 0,
        sellerShare: 0,
        ownerShare: 0,
      );
      final emptyResult = await exporter.exportPdf(empty, 'Boutique vide');
      emptyResult.fold(
        (failure) => fail('${failure.message}: ${failure.cause}'),
        (path) => expect(File(path).existsSync(), isTrue),
      );
    },
  );
}
