import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/navigation/pems_navigation.dart';
import 'core/theme/app_theme.dart';
import 'features/backup/presentation/backup_page.dart';
import 'features/catalog/presentation/catalog_page.dart';
import 'features/reports/presentation/reports_page.dart';
import 'features/sales/presentation/quick_sale_page.dart';
import 'features/sales/presentation/sales_page.dart';
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
          GoRoute(path: '/catalog', builder: (_, _) => const CatalogPage()),
          GoRoute(path: '/sales', builder: (_, _) => const SalesPage()),
          GoRoute(path: '/sales/new', builder: (_, _) => const QuickSalePage()),
          GoRoute(path: '/reports', builder: (_, _) => const ReportsPage()),
        ],
      ),
      GoRoute(
        path: '/shops/:id',
        builder: (_, state) =>
            ShopDetailPage(shopId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/shops/:id/products/new',
        builder: (_, state) =>
            ProductCreationPage(shopId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/backup', builder: (_, _) => const BackupPage()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
    ],
  ),
);

class PemsStoreApp extends ConsumerWidget {
  const PemsStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    return MaterialApp.router(
      title: 'PeMS Store',
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
    final destinations = ['/dashboard', '/shops', '/sales'];
    final found = destinations.indexWhere(location.startsWith);
    final selected = found < 0 ? 0 : found;
    return Scaffold(
      key: pemsShellScaffoldKey,
      drawer: _PemsDrawer(location: location),
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
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Ventes',
          ),
        ],
      ),
    );
  }
}

class _PemsDrawer extends StatelessWidget {
  const _PemsDrawer({required this.location});
  final String location;

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.go(route);
  }

  @override
  Widget build(BuildContext context) => Drawer(
    width: 310,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Image.asset('assets/branding/pems_mark_small.png'),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PeMS STORE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Menu principal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Fermer le menu',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              children: [
                _DrawerDestination(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Accueil',
                  selected: location.startsWith('/dashboard'),
                  onTap: () => _go(context, '/dashboard'),
                ),
                _DrawerDestination(
                  icon: Icons.storefront_outlined,
                  label: 'Boutiques',
                  selected: location.startsWith('/shops'),
                  onTap: () => _go(context, '/shops'),
                ),
                _DrawerDestination(
                  icon: Icons.inventory_2_outlined,
                  label: 'Catalogue & Stock',
                  selected: location.startsWith('/catalog'),
                  onTap: () => _go(context, '/catalog'),
                ),
                _DrawerDestination(
                  icon: Icons.receipt_long_outlined,
                  label: 'Ventes',
                  selected: location.startsWith('/sales'),
                  onTap: () => _go(context, '/sales'),
                ),
                _DrawerDestination(
                  icon: Icons.bar_chart_outlined,
                  label: 'Rapports',
                  selected: location.startsWith('/reports'),
                  onTap: () => _go(context, '/reports'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(),
                ),
                _DrawerDestination(
                  icon: Icons.cloud_sync_outlined,
                  label: 'Sauvegarde & restauration',
                  onTap: () => _go(context, '/backup'),
                ),
                _DrawerDestination(
                  icon: Icons.tune_outlined,
                  label: 'Paramètres',
                  onTap: () => _go(context, '/settings'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'PeMS Store • Gestion commerciale',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DrawerDestination extends StatelessWidget {
  const _DrawerDestination({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: .48),
      leading: Icon(icon),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    ),
  );
}
