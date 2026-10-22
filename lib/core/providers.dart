import 'dart:async';

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
import '../features/inventory/domain/stock_entry.dart';
import '../features/reports/data/pdf_report_exporter.dart';
import '../features/reports/data/sqlite_report_repository.dart';
import '../features/reports/domain/report_repository.dart';
import '../features/reports/domain/weekly_report.dart';
import '../features/sales/data/sqlite_sales_repository.dart';
import '../features/sales/domain/sale.dart';
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
import 'error/result.dart';
import 'security/external_activity_guard.dart';

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
final externalActivityGuardProvider = Provider<ExternalActivityGuard>(
  (_) => ExternalActivityGuard(),
);
final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => DevicePhotoRepository(
    activityGuard: ref.watch(externalActivityGuardProvider),
  ),
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
final listStockEntriesProvider = Provider<ListStockEntries>(
  (ref) => ListStockEntries(ref.watch(inventoryRepositoryProvider)),
);
final recordSaleProvider = Provider<RecordSale>(
  (ref) => RecordSale(ref.watch(salesRepositoryProvider)),
);
final cancelSaleProvider = Provider<CancelSale>(
  (ref) => CancelSale(ref.watch(salesRepositoryProvider)),
);
final listSalesProvider = Provider<ListSales>(
  (ref) => ListSales(ref.watch(salesRepositoryProvider)),
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

enum AuthStatus { setupRequired, signedOut, locked, authenticated }

class AuthSnapshot {
  const AuthSnapshot._({required this.status, this.identifier, this.session});

  const AuthSnapshot.setupRequired() : this._(status: AuthStatus.setupRequired);

  const AuthSnapshot.signedOut([String? identifier])
    : this._(status: AuthStatus.signedOut, identifier: identifier);

  AuthSnapshot.locked(AuthSession session)
    : this._(
        status: AuthStatus.locked,
        identifier: session.identifier,
        session: session,
      );

  AuthSnapshot.authenticated(AuthSession session)
    : this._(
        status: AuthStatus.authenticated,
        identifier: session.identifier,
        session: session,
      );

  final AuthStatus status;
  final String? identifier;
  final AuthSession? session;
}

class AuthController extends AsyncNotifier<AuthSnapshot> {
  Timer? _refreshTimer;
  bool _refreshing = false;

  SecurityRepository get _repository => ref.read(securityRepositoryProvider);

  @override
  Future<AuthSnapshot> build() async {
    ref.onDispose(() => _refreshTimer?.cancel());
    final hasCredentials = await _repository.hasCredentials();
    final configured = hasCredentials.fold(
      (failure) => throw failure,
      (value) => value,
    );
    if (!configured) return const AuthSnapshot.setupRequired();

    final restored = await _repository.restoreSession();
    final session = restored.fold((failure) => throw failure, (value) => value);
    if (session != null) {
      return AuthSnapshot.locked(session);
    }
    return AuthSnapshot.signedOut(await _identifier());
  }

  Future<Result<void>> register({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    final result = await _repository.register(
      identifier: identifier,
      password: password,
      rememberMe: rememberMe,
    );
    return _applySessionResult(result);
  }

  Future<Result<void>> signIn({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    final result = await _repository.signIn(
      identifier: identifier,
      password: password,
      rememberMe: rememberMe,
    );
    return _applySessionResult(result);
  }

  Future<Result<void>> signInWithBiometrics({required bool rememberMe}) async =>
      _applySessionResult(
        await _repository.signInWithBiometrics(rememberMe: rememberMe),
      );

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => _applySessionResult(
    await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    ),
  );

  Future<Result<void>> signOut() async {
    _refreshTimer?.cancel();
    final result = await _repository.signOut();
    return result.fold((failure) => Failure(failure), (_) {
      state = AsyncData(AuthSnapshot.signedOut(state.value?.identifier));
      return const Success(null);
    });
  }

  void lock() {
    final snapshot = state.value;
    if (snapshot?.status != AuthStatus.authenticated ||
        snapshot?.session == null) {
      return;
    }
    _refreshTimer?.cancel();
    state = AsyncData(AuthSnapshot.locked(snapshot!.session!));
  }

  Future<void> ensureFreshSession() async {
    if (_refreshing) return;
    final snapshot = state.value;
    final session = snapshot?.session;
    if (snapshot?.status != AuthStatus.authenticated || session == null) return;
    if (!session.needsRefresh(DateTime.now())) {
      _scheduleRefresh(session);
      return;
    }
    _refreshing = true;
    try {
      final result = await _repository.refreshSession();
      switch (result) {
        case Failure<AuthSession>():
          _refreshTimer?.cancel();
          state = AsyncData(AuthSnapshot.signedOut(await _identifier()));
        case Success<AuthSession>(:final value):
          final refreshed = value;
          state = AsyncData(AuthSnapshot.authenticated(refreshed));
          _scheduleRefresh(refreshed);
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<Result<void>> _applySessionResult(Result<AuthSession> result) async =>
      result.fold((failure) => Failure(failure), (session) {
        state = AsyncData(AuthSnapshot.authenticated(session));
        _scheduleRefresh(session);
        return const Success(null);
      });

  void _scheduleRefresh(AuthSession session) {
    _refreshTimer?.cancel();
    final target = session.accessTokenExpiresAt.subtract(refreshTokenLeeway);
    final delay = target.difference(DateTime.now());
    _refreshTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      unawaited(ensureFreshSession());
    });
  }

  Future<String?> _identifier() async =>
      (await _repository.savedIdentifier()).fold((_) => null, (value) => value);
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSnapshot>(AuthController.new);

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

final stockEntriesProvider = FutureProvider.family<List<StockEntry>, String>((
  ref,
  variantId,
) async {
  final result = await ref.watch(listStockEntriesProvider)(variantId);
  return result.fold((failure) => throw failure, (value) => value);
});

final categoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  shopId,
) async {
  final result = await ref.watch(listCategoriesProvider)(shopId);
  return result.fold((failure) => throw failure, (value) => value);
});

class ReportQuery {
  ReportQuery({required this.shopId, required DateTime anchor})
    : anchor = DateTime(anchor.year, anchor.month, anchor.day);

  final String shopId;
  final DateTime anchor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportQuery && other.shopId == shopId && other.anchor == anchor;

  @override
  int get hashCode => Object.hash(shopId, anchor);
}

final weeklyReportProvider = FutureProvider.family<WeeklyReport, ReportQuery>((
  ref,
  query,
) async {
  final result = await ref.watch(getReportProvider)(query.shopId, query.anchor);
  return result.fold((failure) => throw failure, (value) => value);
});

final salesHistoryProvider = FutureProvider.family<List<SaleSummary>, String?>((
  ref,
  shopId,
) async {
  final result = await ref.watch(listSalesProvider)(shopId: shopId);
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
      weeklyReportProvider(ReportQuery(shopId: shop.id, anchor: DateTime.now()))
          .future,
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
