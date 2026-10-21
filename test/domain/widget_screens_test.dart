import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/core/providers.dart';
import 'package:pasora/features/shops/presentation/dashboard_page.dart';
import 'package:pasora/features/shops/presentation/shops_page.dart';
import 'package:pasora/features/catalog/presentation/catalog_page.dart';
import 'package:pasora/features/sales/presentation/quick_sale_page.dart';

void main() {
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
}
