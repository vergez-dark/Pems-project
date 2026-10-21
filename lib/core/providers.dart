import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/backup/data/google_drive_gateway.dart';
import '../features/backup/data/zip_backup_repository.dart';
import '../features/backup/domain/backup_record.dart';
import '../features/backup/domain/backup_repository.dart';
import '../features/catalog/data/device_photo_repository.dart';
import '../features/catalog/data/sqlite_catalog_repository.dart';
import '../features/catalog/domain/catalog_entities.dart';
import '../features/catalog/domain/catalog_repository.dart';
import '../features/catalog/domain/photo_repository.dart';
import '../features/inventory/data/sqlite_inventory_repository.dart';
import '../features/inventory/domain/inventory_repository.dart';
import '../features/reports/data/pdf_report_exporter.dart';
import '../features/reports/data/sqlite_report_repository.dart';
import '../features/reports/domain/report_repository.dart';
import '../features/reports/domain/weekly_report.dart';
import '../features/sales/data/sqlite_sales_repository.dart';
import '../features/sales/domain/sales_repository.dart';
import '../features/security/data/device_security_repository.dart';
import '../features/security/domain/security_repository.dart';
import '../features/settings/data/preferences_settings_repository.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/settings/domain/settings_repository.dart';
import '../features/shops/data/sqlite_shop_repository.dart';
import '../features/shops/domain/shop.dart';
import '../features/shops/domain/shop_repository.dart';
import 'database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final shopRepositoryProvider = Provider<ShopRepository>(
  (ref) => SqliteShopRepository(ref.watch(databaseProvider)),
);
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => SqliteCatalogRepository(ref.watch(databaseProvider)),
);
final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => SqliteInventoryRepository(ref.watch(databaseProvider)),
);
final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => SqliteSalesRepository(ref.watch(databaseProvider)),
);
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => SqliteReportRepository(
    database: ref.watch(databaseProvider),
    shops: ref.watch(shopRepositoryProvider),
    sales: ref.watch(salesRepositoryProvider),
  ),
);
final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) =>
      ZipBackupRepository(ref.watch(databaseProvider), GoogleDriveGateway()),
);
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (_) => const PreferencesSettingsRepository(),
);
final securityRepositoryProvider = Provider<SecurityRepository>(
  (_) => DeviceSecurityRepository(),
);
final photoRepositoryProvider = Provider<PhotoRepository>(
  (_) => DevicePhotoRepository(),
);
final reportExporterProvider = Provider<ReportExporter>(
  (_) => const PdfReportExporter(),
);

final listShopsProvider = Provider<ListShops>(
  (ref) => ListShops(ref.watch(shopRepositoryProvider)),
);
final saveShopProvider = Provider<SaveShop>(
  (ref) => SaveShop(ref.watch(shopRepositoryProvider)),
);
final archiveShopProvider = Provider<ArchiveShop>(
  (ref) => ArchiveShop(ref.watch(shopRepositoryProvider)),
);
final listCatalogProvider = Provider<ListCatalogItems>(
  (ref) => ListCatalogItems(ref.watch(catalogRepositoryProvider)),
);
final listCategoriesProvider = Provider<ListCategories>(
  (ref) => ListCategories(ref.watch(catalogRepositoryProvider)),
);
final saveCategoryProvider = Provider<SaveCategory>(
  (ref) => SaveCategory(ref.watch(catalogRepositoryProvider)),
);
final saveProductProvider = Provider<SaveProduct>(
  (ref) => SaveProduct(ref.watch(catalogRepositoryProvider)),
);
final updateProductProvider = Provider<UpdateProduct>(
  (ref) => UpdateProduct(ref.watch(catalogRepositoryProvider)),
);
final pickPhotoProvider = Provider<PickProductPhoto>(
  (ref) => PickProductPhoto(ref.watch(photoRepositoryProvider)),
);
final addStockProvider = Provider<AddStockEntry>(
  (ref) => AddStockEntry(ref.watch(inventoryRepositoryProvider)),
);
final updateStockProvider = Provider<UpdateStockEntry>(
  (ref) => UpdateStockEntry(ref.watch(inventoryRepositoryProvider)),
);
final recordSaleProvider = Provider<RecordSale>(
  (ref) => RecordSale(ref.watch(salesRepositoryProvider)),
);
final cancelSaleProvider = Provider<CancelSale>(
  (ref) => CancelSale(ref.watch(salesRepositoryProvider)),
);
final getReportProvider = Provider<GetWeeklyReport>(
  (ref) => GetWeeklyReport(ref.watch(reportRepositoryProvider)),
);
final exportReportProvider = Provider<ExportWeeklyReport>(
  (ref) => ExportWeeklyReport(ref.watch(reportExporterProvider)),
);
final shareReportProvider = Provider<ShareWeeklyReport>(
  (ref) => ShareWeeklyReport(ref.watch(reportExporterProvider)),
);
final exportReportImageProvider = Provider<ExportWeeklyReportImage>(
  (ref) => ExportWeeklyReportImage(ref.watch(reportExporterProvider)),
);
final sendWhatsAppProvider = Provider<SendReportSummaryToWhatsApp>(
  (ref) => SendReportSummaryToWhatsApp(ref.watch(reportExporterProvider)),
);
final createBackupProvider = Provider<CreateBackup>(
  (ref) => CreateBackup(ref.watch(backupRepositoryProvider)),
);
final listBackupsProvider = Provider<ListBackups>(
  (ref) => ListBackups(ref.watch(backupRepositoryProvider)),
);
final restoreBackupProvider = Provider<RestoreBackup>(
  (ref) => RestoreBackup(ref.watch(backupRepositoryProvider)),
);
final authenticateProvider = Provider<AuthenticateOwner>(
  (ref) => AuthenticateOwner(ref.watch(securityRepositoryProvider)),
);
final setPinProvider = Provider<SetPin>(
  (ref) => SetPin(ref.watch(securityRepositoryProvider)),
);
final verifyPinProvider = Provider<VerifyPin>(
  (ref) => VerifyPin(ref.watch(securityRepositoryProvider)),
);

final shopsProvider = FutureProvider<List<Shop>>((ref) async {
  final result = await ref.watch(listShopsProvider)();
  return result.fold((failure) => throw failure, (value) => value);
});

final catalogProvider = FutureProvider.family<List<CatalogItem>, String>((
  ref,
  shopId,
) async {
  final result = await ref.watch(listCatalogProvider)(shopId);
  return result.fold((failure) => throw failure, (value) => value);
});

final categoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  shopId,
) async {
  final result = await ref.watch(listCategoriesProvider)(shopId);
  return result.fold((failure) => throw failure, (value) => value);
});

typedef ReportQuery = ({String shopId, DateTime anchor});
final weeklyReportProvider = FutureProvider.family<WeeklyReport, ReportQuery>((
  ref,
  query,
) async {
  final result = await ref.watch(getReportProvider)(query.shopId, query.anchor);
  return result.fold((failure) => throw failure, (value) => value);
});

final backupsProvider = FutureProvider<List<BackupRecord>>((ref) async {
  final result = await ref.watch(listBackupsProvider)();
  return result.fold((failure) => throw failure, (value) => value);
});

class DashboardSummary {
  const DashboardSummary({
    required this.profit,
    required this.pairsSold,
    required this.lowStock,
    required this.shops,
    this.revenue = 0,
    this.stockQuantity = 0,
    this.reports = const {},
  });
  final int profit;
  final int pairsSold;
  final int lowStock;
  final List<Shop> shops;
  final int revenue;
  final int stockQuantity;
  final Map<String, WeeklyReport> reports;
}

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final shops = await ref.watch(shopsProvider.future);
  var profit = 0;
  var revenue = 0;
  var sold = 0;
  var low = 0;
  var stock = 0;
  final reports = <String, WeeklyReport>{};
  for (final shop in shops) {
    final report = await ref.watch(
      weeklyReportProvider((shopId: shop.id, anchor: DateTime.now())).future,
    );
    reports[shop.id] = report;
    profit += report.profit;
    revenue += report.revenue;
    sold += report.pairsSold;
    final catalog = await ref.watch(catalogProvider(shop.id).future);
    low += catalog.where((item) => item.variant.stockQuantity <= 3).length;
    stock += catalog.fold<int>(
      0,
      (total, item) => total + item.variant.stockQuantity,
    );
  }
  return DashboardSummary(
    profit: profit,
    revenue: revenue,
    pairsSold: sold,
    lowStock: low,
    stockQuantity: stock,
    shops: shops,
    reports: reports,
  );
});

class GlobalCatalogItem {
  const GlobalCatalogItem({required this.shop, required this.item});
  final Shop shop;
  final CatalogItem item;
}

final globalCatalogProvider = FutureProvider<List<GlobalCatalogItem>>((
  ref,
) async {
  final shops = await ref.watch(shopsProvider.future);
  final records = <GlobalCatalogItem>[];
  for (final shop in shops) {
    final catalog = await ref.watch(catalogProvider(shop.id).future);
    records.addAll(
      catalog.map((item) => GlobalCatalogItem(shop: shop, item: item)),
    );
  }
  records.sort(
    (a, b) => a.item.product.name.toLowerCase().compareTo(
      b.item.product.name.toLowerCase(),
    ),
  );
  return records;
});

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final result = await LoadSettings(ref.watch(settingsRepositoryProvider))();
    return result.fold((failure) => throw failure, (value) => value);
  }

  Future<void> save(AppSettings settings) async {
    state = const AsyncLoading();
    final result = await SaveSettings(ref.read(settingsRepositoryProvider))(
      settings,
    );
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => AsyncData(settings),
    );
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
