import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/pems_components.dart';
import '../../../core/widgets/state_views.dart';
import '../../shops/domain/shop.dart';
import '../domain/sale.dart';
import 'sale_details_sheet.dart';

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage> {
  static const _allShops = '__all_shops__';
  String? _shopId;

  @override
  Widget build(BuildContext context) {
    final shops = ref.watch(shopsProvider);
    return Scaffold(
      appBar: const PemsBrandHeader(section: 'Ventes'),
      body: shops.when(
        loading: () => const LoadingCards(),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(shopsProvider),
        ),
        data: _buildContent,
      ),
      floatingActionButton: shops.value?.isNotEmpty == true
          ? FloatingActionButton.extended(
              heroTag: 'create-sale',
              onPressed: () => context.push('/sales/new'),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Nouvelle vente'),
            )
          : null,
    );
  }

  Widget _buildContent(List<Shop> shops) {
    if (shops.isEmpty) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: 'Aucune boutique',
        message: 'Créez une boutique avant d’enregistrer une vente.',
        action: FilledButton.icon(
          onPressed: () => context.go('/shops'),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Créer une boutique'),
        ),
      );
    }

    final selectedShopId = shops.any((shop) => shop.id == _shopId)
        ? _shopId
        : null;
    final history = ref.watch(salesHistoryProvider(selectedShopId));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: PemsDropdownField<String>(
            key: ValueKey(selectedShopId ?? _allShops),
            value: selectedShopId ?? _allShops,
            label: 'Filtrer par boutique',
            leadingIcon: Icons.storefront_outlined,
            items: [
              const DropdownMenuItem(
                value: _allShops,
                child: Text('Toutes les boutiques'),
              ),
              ...shops.map(
                (shop) => DropdownMenuItem(
                  value: shop.id,
                  child: Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) =>
                setState(() => _shopId = value == _allShops ? null : value),
          ),
        ),
        Expanded(
          child: history.when(
            loading: () => const LoadingCards(),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () =>
                  ref.invalidate(salesHistoryProvider(selectedShopId)),
            ),
            data: (sales) => sales.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: selectedShopId == null
                        ? 'Aucune vente enregistrée'
                        : 'Aucune vente pour cette boutique',
                    message: 'La prochaine vente apparaîtra ici avec son montant et son statut.',
                    action: FilledButton.icon(
                      onPressed: () => context.push('/sales/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Créer une vente'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(salesHistoryProvider(selectedShopId)),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                      itemCount: sales.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == 0) return _SalesSummary(sales: sales);
                        return _SaleCard(summary: sales[index - 1]);
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SalesSummary extends StatelessWidget {
  const _SalesSummary({required this.sales});

  final List<SaleSummary> sales;

  @override
  Widget build(BuildContext context) {
    final validated = sales
        .where((item) => item.sale.status == SaleStatus.validated)
        .toList(growable: false);
    final revenue = validated.fold<int>(
      0,
      (sum, item) => sum + item.sale.revenue,
    );
    final pairs = validated.fold<int>(
      0,
      (sum, item) => sum + item.sale.quantity,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(
              label: 'Chiffre d’affaires',
              value: formatMoney(revenue),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: _SummaryValue(label: 'Paires vendues', value: '$pairs'),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
      ),
    ],
  );
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.summary});

  final SaleSummary summary;

  @override
  Widget build(BuildContext context) {
    final sale = summary.sale;
    final cancelled = sale.status == SaleStatus.cancelled;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => SaleDetailsSheet.show(context, summary),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: cancelled
                    ? Theme.of(context).colorScheme.errorContainer
                    : AppColors.roseLight,
                foregroundColor: cancelled
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : AppColors.roseDark,
                child: Icon(
                  cancelled
                      ? Icons.cancel_outlined
                      : Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${summary.shopName} • ${summary.size} • ${summary.color}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          DateFormat(
                            'd MMM yyyy • HH:mm',
                            'fr_FR',
                          ).format(sale.date),
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          '${sale.quantity} paire${sale.quantity > 1 ? 's' : ''} • ${_paymentLabel(sale.paymentMethod)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(sale.revenue),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      decoration: cancelled
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    cancelled ? 'Annulée' : 'Validée',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cancelled ? AppColors.loss : AppColors.profit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _paymentLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'Espèces',
  PaymentMethod.mobileMoney => 'Mobile Money',
  PaymentMethod.card => 'Carte',
};
