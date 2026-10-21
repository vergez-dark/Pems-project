import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasora/app.dart';
import 'package:pasora/core/providers.dart';
import 'package:pasora/core/theme/app_theme.dart';
import 'package:pasora/features/security/data/device_security_repository.dart';
import 'package:pasora/features/security/presentation/security_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('le premier lancement demande les futurs identifiants', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const AuthenticationPage(setup: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Configurez votre accès'), findsOneWidget);
    expect(find.text('IDENTIFIANT OU E-MAIL'), findsOneWidget);
    expect(find.text('CRÉER UN MOT DE PASSE'), findsOneWidget);
    expect(find.text('CONFIRMER LE MOT DE PASSE'), findsOneWidget);
    expect(find.textContaining('ex: jean.dupont'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la connexion reprend la maquette sans exemple sous identifiant',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const AuthenticationPage(savedIdentifier: 'proprietaire'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bienvenue sur PeMS Store'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
      expect(find.textContaining('ex: jean.dupont'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('capture de l’écran de connexion', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const AuthenticationPage(),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/pems_mark_small.png'),
        tester.element(find.byType(AuthenticationPage)),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AuthenticationPage),
      matchesGoldenFile('../../docs/screenshots/authentication.png'),
    );
  });

  testWidgets('le démarrage réel fournit un Overlay à l’authentification', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: PemsStoreApp()));
    await tester.pumpAndSettle();

    expect(find.text('Configurez votre accès'), findsOneWidget);
    expect(find.byType(Overlay), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toutes les routes restent stables sur un petit écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(
      () => DeviceSecurityRepository(passwordIterations: 20).register(
        identifier: 'proprietaire',
        password: 'MotDePasse!42',
        rememberMe: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        dashboardProvider.overrideWith(
          (ref) async => const DashboardSummary(
            profit: 0,
            pairsSold: 0,
            lowStock: 0,
            shops: [],
          ),
        ),
        shopsProvider.overrideWith((ref) async => []),
        globalCatalogProvider.overrideWith((ref) async => []),
        backupsProvider.overrideWith((ref) async => []),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PemsStoreApp(),
      ),
    );
    await _pumpApplicationFrames(tester);

    final router = container.read(routerProvider);
    for (final route in [
      '/dashboard',
      '/shops',
      '/catalog',
      '/sales',
      '/reports',
      '/backup',
      '/settings',
      '/shops/introuvable',
    ]) {
      router.go(route);
      await _pumpApplicationFrames(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: 'La route $route ne doit produire aucune exception.',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });
}

Future<void> _pumpApplicationFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
