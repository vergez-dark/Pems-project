import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/pems_components.dart';
import '../../../core/widgets/state_views.dart';
import '../../catalog/domain/catalog_entities.dart';
import '../../shops/domain/shop.dart';

class StockDetailsSheet extends ConsumerWidget {
  const StockDetailsSheet({
    super.key,
    required this.shop,
    required this.item,
    this.onAddStock,
  });

  final Shop shop;
  final CatalogItem item;
  final VoidCallback? onAddStock;

  static Future<void> show(
    BuildContext context, {
    required Shop shop,
    required CatalogItem item,
    VoidCallback? onAddStock,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        StockDetailsSheet(shop: shop, item: item, onAddStock: onAddStock),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(stockEntriesProvider(item.variant.id));
    final stock = item.variant.stockQuantity;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .82,
      minChildSize: .6,
      maxChildSize: .95,
      builder: (context, controller) => CustomScrollView(
        controller: controller,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    PemsPhoto(
                      photoPath: item.product.photoPath,
                      width: 72,
                      height: 72,
                      placeholderIcon: Icons.checkroom_rounded,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            '${item.categoryName} • ${item.variant.size} • ${item.variant.color}',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(shop.name),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Stock disponible',
                        value: '$stock',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Metric(
                        label: 'Prix conseillé',
                        value: formatMoney(item.suggestedUnitSalePrice),
                        icon: Icons.sell_outlined,
                      ),
                    ),
                  ],
                ),
                if (item.product.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.notes_rounded),
                      title: const Text('Notes'),
                      subtitle: Text(item.product.notes),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Historique des entrées',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (onAddStock != null)
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(context);
                          onAddStock!();
                        },
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('Ajouter'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          entries.when(
            loading: () => const SliverFillRemaining(child: LoadingCards()),
            error: (error, _) => SliverFillRemaining(
              child: ErrorState(
                error: error,
                onRetry: () =>
                    ref.invalidate(stockEntriesProvider(item.variant.id)),
              ),
            ),
            data: (items) => items.isEmpty
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Aucune entrée',
                      message: 'Aucun mouvement de stock n’est disponible.',
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final entry = items[index];
                        final sold = entry.quantity - entry.remainingQuantity;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      child: Text('${entry.quantity}×'),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            formatDay(entry.date),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            '$sold vendue${sold > 1 ? 's' : ''} • ${entry.remainingQuantity} restante${entry.remainingQuantity > 1 ? 's' : ''}',
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      formatMoney(entry.plannedUnitSalePrice),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 18,
                                  runSpacing: 5,
                                  alignment: WrapAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Achat ${formatMoney(entry.unitPurchasePrice)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Coût rendu ${formatMoney(entry.unitLandedCost)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: .35),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.roseDark),
        const SizedBox(height: 10),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}
