import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/backup/presentation/backup_page.dart';
import 'features/reports/presentation/reports_page.dart';
import 'features/settings/domain/app_settings.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/security/presentation/security_gate.dart';
import 'features/shops/presentation/dashboard_page.dart';
import 'features/shops/presentation/onboarding_page.dart';
import 'features/shops/presentation/shop_detail_page.dart';
import 'features/shops/presentation/shops_page.dart';

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const OnboardingGate()),
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          GoRoute(path: '/shops', builder: (_, _) => const ShopsPage()),
          GoRoute(path: '/reports', builder: (_, _) => const ReportsPage()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        ],
      ),
      GoRoute(
        path: '/shops/:id',
        builder: (_, state) =>
            ShopDetailPage(shopId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/backup', builder: (_, _) => const BackupPage()),
    ],
  ),
);

class PasoraApp extends ConsumerWidget {
  const PasoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    return MaterialApp.router(
      title: 'Pasora',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (settings.themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      builder: (_, child) =>
          SecurityGate(child: child ?? const SizedBox.shrink()),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final destinations = ['/dashboard', '/shops', '/reports', '/settings'];
    final found = destinations.indexWhere(location.startsWith);
    final selected = found < 0 ? 0 : found;
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => context.go(destinations[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Boutiques',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Rapports',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Réglages',
          ),
        ],
      ),
    );
  }
}
