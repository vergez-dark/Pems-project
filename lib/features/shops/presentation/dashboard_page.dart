import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour 👋',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text('Vue d’ensemble'),
          ],
        ),
        actions: [
          IconButton.filledTonal(
            onPressed: () => context.push('/backup'),
            icon: const Icon(Icons.cloud_done_outlined),
            tooltip: 'Sauvegarde',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider),
        child: summary.when(
          loading: () => const LoadingCards(),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.forest,
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [AppColors.forest, Color(0xFF246348)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bénéfice cette semaine',
                      style: TextStyle(color: Color(0xFFC7DED2), fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatMoney(data.profit),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        _HeroStat(
                          icon: Icons.shopping_bag_outlined,
                          value: '${data.pairsSold}',
                          label: 'paires vendues',
                        ),
                        const SizedBox(width: 12),
                        _HeroStat(
                          icon: Icons.storefront_outlined,
                          value: '${data.shops.length}',
                          label: 'boutiques actives',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (data.lowStock > 0)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                      ),
                    ),
                    title: Text(
                      '${data.lowStock} stock${data.lowStock > 1 ? 's' : ''} à surveiller',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('3 paires ou moins disponibles'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/shops'),
                  ),
                ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Vos boutiques',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/shops'),
                    child: const Text('Tout voir'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (data.shops.isEmpty)
                Card(
                  child: EmptyState(
                    icon: Icons.storefront,
                    title: 'Créez votre première boutique',
                    message: 'Ajoutez une vendeuse ou un point de vente pour commencer.',
                    action: FilledButton(
                      onPressed: () => context.go('/shops'),
                      child: const Text('Ajouter une boutique'),
                    ),
                  ),
                )
              else
                ...data.shops
                    .take(4)
                    .map(
                      (shop) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              child: Text(
                                shop.name.substring(0, 1).toUpperCase(),
                              ),
                            ),
                            title: Text(
                              shop.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              shop.sellerName.isEmpty
                                  ? 'Aucune vendeuse renseignée'
                                  : shop.sellerName,
                            ),
                            trailing: const Icon(Icons.arrow_forward_rounded),
                            onTap: () => context.push('/shops/${shop.id}'),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.lime),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC7DED2),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
