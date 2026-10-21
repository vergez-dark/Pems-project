import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/core/providers.dart';
import 'package:pasora/core/theme/app_theme.dart';
import 'package:pasora/features/shops/domain/shop.dart';
import 'package:pasora/features/shops/presentation/dashboard_page.dart';
import 'package:pasora/features/shops/presentation/shops_page.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.otf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Medium.otf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Bold.otf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-ExtraBold.otf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('assets/fonts/MaterialIcons-Regular.otf'));
    await Future.wait([inter.load(), icons.load()]);
  });

  final shop = Shop(
    id: 'demo',
    name: 'Boutique Akwa',
    sellerName: 'Mireille',
    whatsapp: '237600000000',
    compensationType: CompensationType.percentage,
    percentageRate: 20,
    compensationBasis: CompensationBasis.profit,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('capture du tableau de bord', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) async => DashboardSummary(
              profit: 52400,
              pairsSold: 14,
              lowStock: 2,
              shops: [shop],
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(DashboardPage),
      matchesGoldenFile('../docs/screenshots/dashboard.png'),
    );
  });

  testWidgets('capture de la liste boutiques', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopsProvider.overrideWith((ref) async => [shop]),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const ShopsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ShopsPage),
      matchesGoldenFile('../docs/screenshots/shops.png'),
    );
  });
}
