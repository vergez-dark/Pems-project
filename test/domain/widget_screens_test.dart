import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pasora/core/providers.dart';
import 'package:pasora/core/widgets/pems_components.dart';
import 'package:pasora/features/catalog/domain/catalog_entities.dart';
import 'package:pasora/features/inventory/domain/stock_entry.dart';
import 'package:pasora/features/reports/domain/weekly_report.dart';
import 'package:pasora/features/sales/domain/sale.dart';
import 'package:pasora/features/shops/presentation/dashboard_page.dart';
import 'package:pasora/features/shops/presentation/shops_page.dart';
import 'package:pasora/features/catalog/presentation/catalog_page.dart';
import 'package:pasora/features/sales/presentation/quick_sale_page.dart';
import 'package:pasora/features/sales/presentation/sales_page.dart';
import 'package:pasora/features/shops/domain/shop.dart';
import 'package:pasora/features/shops/presentation/shop_detail_page.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('une requête de bilan reste stable pendant toute la journée', () {
    final morning = ReportQuery(
      shopId: 'shop',
      anchor: DateTime(2026, 10, 21, 8, 15),
    );
    final evening = ReportQuery(
      shopId: 'shop',
      anchor: DateTime(2026, 10, 21, 19, 45),
    );

    expect(morning, evening);
    expect(morning.hashCode, evening.hashCode);
    expect(morning.anchor, DateTime(2026, 10, 21));
  });

  testWidgets('flèche de page revient à l’accueil sans historique', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('Accueil cible')),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(
            appBar: PemsBrandHeader(section: 'Paramètres', showBack: true),
            body: Text('Paramètres'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Accueil cible'), findsOneWidget);
  });

  testWidgets('tableau de bord affiche les métriques clés', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) async => const DashboardSummary(
              profit: 7000,
              pairsSold: 2,
              lowStock: 1,
              shops: [],
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('7 000 FCFA'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('stock à surveiller'), findsOneWidget);
  });

  testWidgets('liste boutiques affiche un état vide actionnable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [shopsProvider.overrideWith((ref) async => [])],
        child: const MaterialApp(home: ShopsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aucune boutique'), findsOneWidget);
    expect(find.text('Créer la première'), findsOneWidget);
    await tester.tap(find.text('Créer la première'));
    await tester.pumpAndSettle();
    expect(find.byType(SegmentedButton<CompensationType>), findsOneWidget);
    expect(find.text('Sans %'), findsOneWidget);
    expect(find.text('Pourcentage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalogue global affiche son état vide sans débordement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopsProvider.overrideWith((ref) async => []),
          globalCatalogProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: CatalogPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Catalogue vide'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caisse rapide exige une boutique réelle', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [shopsProvider.overrideWith((ref) async => [])],
        child: const MaterialApp(home: QuickSalePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aucune boutique'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('historique des ventes filtre les résultats par boutique', (
    tester,
  ) async {
    final akwa = _shop('akwa', 'Boutique Akwa');
    final bastos = _shop('bastos', 'Boutique Bastos');
    final akwaSale = _saleSummary(
      id: 'sale-akwa',
      shop: akwa,
      productName: 'Escarpins Rose',
    );
    final bastosSale = _saleSummary(
      id: 'sale-bastos',
      shop: bastos,
      productName: 'Baskets Noires',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopsProvider.overrideWith((ref) async => [akwa, bastos]),
          salesHistoryProvider(null)
              .overrideWith((ref) async => [akwaSale, bastosSale]),
          salesHistoryProvider(akwa.id).overrideWith((ref) async => [akwaSale]),
          salesHistoryProvider(bastos.id)
              .overrideWith((ref) async => [bastosSale]),
        ],
        child: const MaterialApp(home: SalesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Escarpins Rose'), findsOneWidget);
    expect(find.text('Baskets Noires'), findsOneWidget);
    expect(find.text('Nouvelle vente'), findsOneWidget);

    await tester.tap(find.text('Toutes les boutiques'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boutique Akwa').last);
    await tester.pumpAndSettle();

    expect(find.text('Escarpins Rose'), findsOneWidget);
    expect(find.text('Baskets Noires'), findsNothing);

    await tester.tap(find.text('Escarpins Rose'));
    await tester.pumpAndSettle();
    expect(find.text('Détails de la vente'), findsOneWidget);
    expect(find.text('Montant total encaissé'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Annuler cette vente'),
      find.byType(Scrollable).last,
      const Offset(0, -200),
    );
    await tester.tap(find.text('Annuler cette vente'));
    await tester.pumpAndSettle();
    expect(find.text('Annuler cette vente ?'), findsOneWidget);
    await tester.tap(find.text('Conserver'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('un article ouvre les détails et les lots de stock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final shop = _shop('akwa', 'Boutique Akwa');
    final item = CatalogItem(
      product: const Product(
        id: 'product',
        shopId: 'akwa',
        categoryId: 'category',
        name: 'Escarpins Rose',
      ),
      variant: const ProductVariant(
        id: 'variant',
        productId: 'product',
        size: '40',
        color: 'Rose',
        stockQuantity: 8,
      ),
      categoryName: 'Escarpins',
      suggestedUnitSalePrice: 12000,
    );
    final entry = StockEntry(
      id: 'entry',
      shopId: shop.id,
      productId: item.product.id,
      variantId: item.variant.id,
      date: DateTime(2026, 10, 20),
      quantity: 10,
      remainingQuantity: 8,
      unitPurchasePrice: 8000,
      transportCost: 5000,
      plannedUnitSalePrice: 12000,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopsProvider.overrideWith((ref) async => [shop]),
          globalCatalogProvider.overrideWith(
            (ref) async => [GlobalCatalogItem(shop: shop, item: item)],
          ),
          stockEntriesProvider(item.variant.id)
              .overrideWith((ref) async => [entry]),
        ],
        child: const MaterialApp(home: CatalogPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Escarpins Rose'));
    await tester.pumpAndSettle();

    expect(find.text('Historique des entrées'), findsOneWidget);
    expect(find.textContaining('2 vendues'), findsOneWidget);
    expect(find.textContaining('Coût rendu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'les onglets Ventes et Bilan chargent le rapport de la boutique',
    (tester) async {
      tester.view.physicalSize = const Size(420, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final shop = _shop('akwa', 'Boutique Akwa');
      final sale = _saleSummary(
        id: 'sale-week',
        shop: shop,
        productName: 'Escarpins Rose',
      ).sale;
      final report = WeeklyReport(
        shopId: shop.id,
        start: DateTime(2026, 10, 19),
        endExclusive: DateTime(2026, 10, 26),
        salesCount: 1,
        pairsSold: 2,
        revenue: 24000,
        landedCost: 17000,
        profit: 7000,
        remainingStock: 8,
        remainingStockValue: 68000,
        sellerShare: 0,
        ownerShare: 7000,
        sales: [sale],
      );
      final query = ReportQuery(shopId: shop.id, anchor: DateTime.now());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopsProvider.overrideWith((ref) async => [shop]),
            catalogProvider(shop.id).overrideWith((ref) async => []),
            weeklyReportProvider(query).overrideWith((ref) async => report),
          ],
          child: MaterialApp(home: ShopDetailPage(shopId: shop.id)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ventes'));
      await tester.pumpAndSettle();
      expect(find.text('24 000 FCFA'), findsOneWidget);

      await tester.tap(find.text('Bilan'));
      await tester.pumpAndSettle();
      expect(find.text('7 000 FCFA'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Shop _shop(String id, String name) => Shop(
  id: id,
  name: name,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

SaleSummary _saleSummary({
  required String id,
  required Shop shop,
  required String productName,
}) => SaleSummary(
  sale: Sale(
    id: id,
    shopId: shop.id,
    variantId: 'variant-$id',
    date: DateTime(2026, 10, 21, 10, 30),
    quantity: 2,
    actualUnitSalePrice: 12000,
    frozenUnitLandedCost: 8500,
  ),
  shopName: shop.name,
  productName: productName,
  size: '40',
  color: 'Rose',
);
