import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/pems_components.dart';
import '../../../core/widgets/state_views.dart';
import '../../catalog/domain/catalog_entities.dart';
import '../../shops/domain/shop.dart';
import '../domain/sale.dart';

class QuickSalePage extends ConsumerStatefulWidget {
  const QuickSalePage({super.key, this.initialShopId});
  final String? initialShopId;

  @override
  ConsumerState<QuickSalePage> createState() => _QuickSalePageState();
}

class _QuickSalePageState extends ConsumerState<QuickSalePage> {
  String? _shopId;
  String? _variantId;
  int _quantity = 1;
  PaymentMethod _payment = PaymentMethod.cash;
  final _price = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _shopId = widget.initialShopId;
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _selectItem(CatalogItem item) {
    setState(() {
      _variantId = item.variant.id;
      _quantity = 1;
      _price.text = '${item.suggestedUnitSalePrice}';
    });
  }

  Future<void> _save(Shop shop, CatalogItem item) async {
    final price = int.tryParse(_price.text.replaceAll(RegExp(r'\s'), '')) ?? -1;
    if (price <= 0) {
      showMessage(context, 'Renseignez un prix de vente valide.', error: true);
      return;
    }
    if (_quantity > item.variant.stockQuantity) {
      showMessage(context, 'Stock insuffisant pour cette vente.', error: true);
      return;
    }
    setState(() => _saving = true);
    final result = await ref.read(recordSaleProvider)(
      id: const Uuid().v4(),
      shopId: shop.id,
      variantId: item.variant.id,
      quantity: _quantity,
      unitSalePrice: price,
      date: DateTime.now(),
      paymentMethod: _payment,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (failure) => showMessage(context, failure.message, error: true),
      (_) {
        ref.invalidate(catalogProvider(shop.id));
        ref.invalidate(globalCatalogProvider);
        ref.invalidate(dashboardProvider);
        ref.invalidate(
          weeklyReportProvider(
            ReportQuery(shopId: shop.id, anchor: DateTime.now()),
          ),
        );
        ref.invalidate(salesHistoryProvider(null));
        ref.invalidate(salesHistoryProvider(shop.id));
        showMessage(context, 'Vente enregistrée et stock mis à jour.');
        context.go('/sales');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(shopsProvider);
    return Scaffold(
      appBar: const PemsBrandHeader(
        section: 'Nouvelle vente',
        showBack: true,
        showMenu: false,
      ),
      body: shopsAsync.when(
        loading: () => const LoadingCards(),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(shopsProvider),
        ),
        data: (shops) {
          if (shops.isEmpty) {
            return const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'Aucune boutique',
              message: 'Créez une boutique avant d’enregistrer une vente.',
            );
          }
          final validShopId = shops.any((shop) => shop.id == _shopId)
              ? _shopId!
              : shops.first.id;
          final shop = shops.firstWhere((item) => item.id == validShopId);
          final catalog = ref.watch(catalogProvider(shop.id));
          return catalog.when(
            loading: () => const LoadingCards(),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(catalogProvider(shop.id)),
            ),
            data: (items) {
              final available = items
                  .where((item) => item.variant.stockQuantity > 0)
                  .toList();
              if (available.isEmpty) {
                return EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Stock indisponible',
                  message:
                      'Ajoutez du stock à ${shop.name} avant d’enregistrer une vente.',
                );
              }
              final selected =
                  available
                      .where((item) => item.variant.id == _variantId)
                      .firstOrNull ??
                  available.first;
              if (_variantId == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _variantId == null) _selectItem(selected);
                });
              }
              return _buildForm(shops, shop, available, selected);
            },
          );
        },
      ),
    );
  }

  Widget _buildForm(
    List<Shop> shops,
    Shop shop,
    List<CatalogItem> available,
    CatalogItem item,
  ) {
    final unitPrice =
        int.tryParse(_price.text.replaceAll(RegExp(r'\s'), '')) ?? 0;
    final total = unitPrice * _quantity;
    final commission = shop.compensationType == CompensationType.percentage
        ? (total * shop.percentageRate / 100).round()
        : 0;
    final enough = _quantity <= item.variant.stockQuantity;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRANSACTION POINT DE VENTE',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: .8,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    'Nouvelle Vente Rapide',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 142,
              child: PemsDropdownField<String>(
                value: shop.id,
                leadingIcon: Icons.storefront,
                items: shops
                    .map(
                      (value) => DropdownMenuItem(
                        value: value.id,
                        child: Text(
                          value.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _shopId = value;
                  _variantId = null;
                  _price.clear();
                  _quantity = 1;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _StepCard(
          number: 1,
          title: 'ARTICLE SÉLECTIONNÉ',
          child: Column(
            children: [
              PemsDropdownField<String>(
                key: ValueKey('${shop.id}-${item.variant.id}'),
                value: item.variant.id,
                label: 'Article et variante',
                leadingIcon: Icons.checkroom_outlined,
                items: available
                    .map(
                      (value) => DropdownMenuItem(
                        value: value.variant.id,
                        child: Text(
                          '${value.product.name} • ${value.variant.size} • ${value.variant.color}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) => _selectItem(
                  available.firstWhere((value) => value.variant.id == id),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _ProductThumb(item: item),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PemsPill(
                          label: 'EN RAYON',
                          backgroundColor: AppColors.profit.withValues(
                            alpha: .14,
                          ),
                          foregroundColor: AppColors.profit,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.product.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatMoney(item.suggestedUnitSalePrice),
                          style: const TextStyle(
                            color: AppColors.roseDark,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _StepCard(
          number: 2,
          title: 'VARIANTE & DISPONIBILITÉ',
          trailing: PemsPill(
            icon: Icons.circle,
            label:
                '${item.variant.stockQuantity} paire${item.variant.stockQuantity > 1 ? 's' : ''} en stock',
            backgroundColor: enough
                ? AppColors.profit.withValues(alpha: .18)
                : AppColors.loss.withValues(alpha: .16),
            foregroundColor: enough ? AppColors.profit : AppColors.loss,
          ),
          child: Row(
            children: [
              Expanded(
                child: _InfoBlock(
                  label: 'Pointure',
                  value: '${item.variant.size} EU',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoBlock(label: 'Couleur', value: item.variant.color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _StepCard(
          number: 3,
          title: 'QUANTITÉ À ENCAISSER',
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        enough
                            ? item.variant.stockQuantity == _quantity
                                  ? 'Stock complet alloué'
                                  : 'Reste ${item.variant.stockQuantity - _quantity}'
                            : 'Dépassement de stock',
                        style: TextStyle(
                          color: enough
                              ? Theme.of(context).colorScheme.tertiary
                              : AppColors.loss,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed: _quantity < item.variant.stockQuantity
                      ? () => setState(() => _quantity++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _StepCard(
          number: 4,
          title: 'ATTRIBUTION VENDEUSE',
          trailing: shop.compensationType == CompensationType.percentage
              ? PemsPill(
                  label: 'Taux ${shop.percentageRate}%',
                  backgroundColor: AppColors.gold.withValues(alpha: .34),
                  foregroundColor: const Color(0xFF765A25),
                )
              : null,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.person_outline),
            ),
            title: Text(
              shop.sellerName.isEmpty
                  ? 'Vendeuse non renseignée'
                  : shop.sellerName,
            ),
            subtitle: Text(shop.name),
            trailing: commission > 0
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Commission', style: TextStyle(fontSize: 11)),
                      Text(
                        '+ ${formatMoney(commission)}',
                        style: const TextStyle(
                          color: Color(0xFF765A25),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: .25),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              TextField(
                controller: _price,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prix unitaire',
                  suffixText: 'FCFA',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL NET À ENCAISSER',
                    style: TextStyle(fontSize: 12, letterSpacing: .8),
                  ),
                  Text(
                    formatMoney(total),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MODE DE PAIEMENT',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    letterSpacing: .7,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<PaymentMethod>(
                segments: const [
                  ButtonSegment(
                    value: PaymentMethod.cash,
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Espèces'),
                  ),
                  ButtonSegment(
                    value: PaymentMethod.mobileMoney,
                    icon: Icon(Icons.phone_android),
                    label: Text('MoMo'),
                  ),
                  ButtonSegment(
                    value: PaymentMethod.card,
                    icon: Icon(Icons.credit_card),
                    label: Text('Carte'),
                  ),
                ],
                selected: {_payment},
                onSelectionChanged: (value) =>
                    setState(() => _payment = value.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving || !enough || total <= 0
              ? null
              : () => _save(shop, item),
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward),
          label: Text(
            _saving
                ? 'Enregistrement…'
                : 'Valider la vente (${formatMoney(total)})',
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.child,
    this.trailing,
  });
  final int number;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    letterSpacing: .7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: .25),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.item});
  final CatalogItem item;
  @override
  Widget build(BuildContext context) {
    final path = item.product.photoPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: path != null && File(path).existsSync()
          ? Image.file(File(path), width: 88, height: 88, fit: BoxFit.cover)
          : Container(
              width: 88,
              height: 88,
              color: Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: .45),
              child: const Icon(Icons.checkroom_rounded, size: 36),
            ),
    );
  }
}
