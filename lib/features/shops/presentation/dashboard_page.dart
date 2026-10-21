import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/pems_components.dart';
import '../../../core/widgets/state_views.dart';
import '../../reports/domain/weekly_report.dart';
import '../domain/shop.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: PemsBrandHeader(
        actions: [
          IconButton(
            onPressed: () => context.push('/backup'),
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Sauvegarde et alertes',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filled(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.person_outline_rounded),
              tooltip: 'Profil et réglages',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(globalCatalogProvider);
        },
        child: summary.when(
          loading: () => const LoadingCards(),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (data) => _DashboardContent(data: data),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data});
  final DashboardSummary data;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: .32),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PemsPill(
                icon: Icons.workspace_premium_outlined,
                label: 'Propriétaire principal',
              ),
              const SizedBox(height: 12),
              Text(
                'Bonjour 👋',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                data.shops.isEmpty
                    ? 'Créez votre premier point de vente pour démarrer.'
                    : 'Supervision de ${data.shops.length} boutique${data.shops.length > 1 ? 's' : ''} • données de la semaine',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _PeriodBanner(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: PemsMetricCard(
                label: 'Chiffre d’affaires',
                value: formatMoney(data.revenue),
                icon: Icons.payments_outlined,
                detail: 'Semaine en cours',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PemsMetricCard(
                label: 'Bénéfice net',
                value: formatMoney(data.profit),
                icon: Icons.account_balance_wallet_outlined,
                detail: data.revenue == 0
                    ? 'Aucune vente'
                    : '${(data.profit * 100 / data.revenue).round()}% de marge',
                accent: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PemsMetricCard(
                label: 'Paires vendues',
                value: '${data.pairsSold}',
                icon: Icons.point_of_sale_outlined,
                detail: 'Sur la période',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PemsMetricCard(
                label: 'Stock disponible',
                value: '${data.stockQuantity}',
                icon: Icons.inventory_2_outlined,
                detail:
                    '${data.lowStock} alerte${data.lowStock > 1 ? 's' : ''}',
                accent: data.lowStock > 0
                    ? AppColors.warning
                    : AppColors.profit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const PemsSectionTitle(
          title: 'Raccourcis de gestion',
          trailing: Text(
            'Opérations directes',
            style: TextStyle(color: AppColors.gold, fontSize: 11),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            PemsActionTile(
              icon: Icons.point_of_sale_outlined,
              label: '+ Vente',
              selected: true,
              onTap: () => context.go('/sales'),
            ),
            const SizedBox(width: 8),
            PemsActionTile(
              icon: Icons.add_shopping_cart_outlined,
              label: '+ Stock',
              onTap: () => context.go('/catalog'),
            ),
            const SizedBox(width: 8),
            PemsActionTile(
              icon: Icons.storefront_outlined,
              label: 'Boutiques',
              onTap: () => context.go('/shops'),
            ),
            const SizedBox(width: 8),
            PemsActionTile(
              icon: Icons.share_outlined,
              label: 'Rapport',
              onTap: () => context.go('/reports'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        PemsSectionTitle(
          title: 'Performance par boutique',
          count: data.shops.length,
          trailing: TextButton(
            onPressed: () => context.go('/shops'),
            child: const Text('Voir tout'),
          ),
        ),
        const SizedBox(height: 8),
        if (data.shops.isEmpty)
          Card(
            child: EmptyState(
              icon: Icons.storefront,
              title: 'Créez votre première boutique',
              message: 'Ajoutez un point de vente pour commencer à suivre votre activité.',
              action: FilledButton(
                onPressed: () => context.go('/shops'),
                child: const Text('Ajouter une boutique'),
              ),
            ),
          )
        else
          ...data.shops.map(
            (shop) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _ShopPerformanceCard(
                shop: shop,
                report: data.reports[shop.id],
              ),
            ),
          ),
        if (data.lowStock > 0) ...[
          const SizedBox(height: 14),
          PemsSectionTitle(
            title: 'Alertes de stock',
            trailing: TextButton(
              onPressed: () => context.go('/catalog'),
              child: const Text('Voir le stock'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.loss.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.notification_important_outlined,
                  color: AppColors.loss,
                ),
              ),
              title: Text(
                '${data.lowStock} stock${data.lowStock > 1 ? 's' : ''} à surveiller',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Articles à 3 paires ou moins, ruptures incluses.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/catalog'),
            ),
          ),
        ],
      ],
    ),
  );
}

class _PeriodBanner extends StatelessWidget {
  const _PeriodBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        Icon(Icons.calendar_view_week_outlined, size: 19),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Cette semaine',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          'Données consolidées',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _ShopPerformanceCard extends StatelessWidget {
  const _ShopPerformanceCard({required this.shop, this.report});
  final Shop shop;
  final WeeklyReport? report;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer
              .withValues(alpha: .45),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.storefront_outlined),
      ),
      title: Text(
        shop.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        shop.sellerName.isEmpty ? 'Vendeuse non renseignée' : shop.sellerName,
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatMoney(report?.revenue ?? 0),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '${report?.pairsSold ?? 0} paire${(report?.pairsSold ?? 0) > 1 ? 's' : ''}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
      onTap: () => context.push('/shops/${shop.id}'),
    ),
  );
}
