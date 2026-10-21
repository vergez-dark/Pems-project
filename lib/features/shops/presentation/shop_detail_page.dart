import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../catalog/domain/catalog_entities.dart';
import '../../inventory/domain/stock_entry.dart';
import '../../shops/domain/shop.dart';
import 'shops_page.dart';

class ShopDetailPage extends ConsumerWidget {
  const ShopDetailPage({super.key, required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shops = ref.watch(shopsProvider);
    return shops.when(
      loading: () => const Scaffold(body: LoadingCards()),
      error: (error, _) => Scaffold(
        body: ErrorState(
          error: error,
          onRetry: () => ref.invalidate(shopsProvider),
        ),
      ),
      data: (items) {
        final matches = items.where((item) => item.id == shopId);
        if (matches.isEmpty) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.storefront,
              title: 'Boutique introuvable',
              message: 'Elle a peut-être été archivée.',
            ),
          );
        }
        final shop = matches.first;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name),
                  if (shop.sellerName.isNotEmpty)
                    Text(
                      shop.sellerName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await showDialog<void>(
                        context: context,
                        builder: (_) => ShopFormDialog(shop: shop),
                      );
                    } else if (value == 'archive') {
                      final result = await ref.read(archiveShopProvider)(
                        shop.id,
                        true,
                      );
                      if (!context.mounted) return;
                      result.fold(
                        (f) => showMessage(context, f.message, error: true),
                        (_) {
                          ref.invalidate(shopsProvider);
                          context.pop();
                        },
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Modifier'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: ListTile(
                        leading: Icon(Icons.archive_outlined),
                        title: Text('Archiver'),
                      ),
                    ),
                  ],
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Stock'),
                  Tab(text: 'Ventes'),
                  Tab(text: 'Bilan'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _StockTab(shop: shop),
                _SalesTab(shop: shop),
                _ReportTab(shop: shop),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StockTab extends ConsumerWidget {
  const _StockTab({required this.shop});
  final Shop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider(shop.id));
    return catalog.when(
      loading: () => const LoadingCards(),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(catalogProvider(shop.id)),
      ),
      data: (items) => Stack(
        children: [
          if (items.isEmpty)
            EmptyState(
              icon: Icons.checkroom_rounded,
              title: 'Catalogue vide',
              message: 'Ajoutez un article, sa pointure et sa première entrée de stock.',
              action: FilledButton.icon(
                onPressed: () => _showProductForm(context, shop.id),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un article'),
              ),
            )
          else
            RefreshIndicator(
              onRefresh: () async => ref.invalidate(catalogProvider(shop.id)),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final item = items[index];
                  final low = item.variant.stockQuantity <= 3;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child:
                                item.product.photoPath != null &&
                                    File(item.product.photoPath!).existsSync()
                                ? Image.file(
                                    File(item.product.photoPath!),
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 64,
                                    height: 64,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    child: const Icon(Icons.checkroom_rounded),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${item.categoryName} • ${item.variant.size} • ${item.variant.color}',
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${item.variant.stockQuantity} en stock',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: low
                                        ? AppColors.warning
                                        : AppColors.profit,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () =>
                                _showStockForm(context, shop.id, item),
                            icon: const Icon(Icons.add_box_outlined),
                            tooltip: 'Entrée de stock',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          Positioned(
            right: 20,
            bottom: 22,
            child: FloatingActionButton.extended(
              heroTag: 'add-product-${shop.id}',
              onPressed: () => _showProductForm(context, shop.id),
              icon: const Icon(Icons.add),
              label: const Text('Article'),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductForm(BuildContext context, String shopId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ProductFormSheet(shopId: shopId),
      );

  void _showStockForm(BuildContext context, String shopId, CatalogItem item) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => StockFormSheet(shopId: shopId, item: item),
      );
}

class _SalesTab extends ConsumerWidget {
  const _SalesTab({required this.shop});
  final Shop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider(shop.id));
    final report = ref.watch(
      weeklyReportProvider((shopId: shop.id, anchor: DateTime.now())),
    );
    return Stack(
      children: [
        report.when(
          loading: () => const LoadingCards(),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(
              weeklyReportProvider((shopId: shop.id, anchor: DateTime.now())),
            ),
          ),
          data: (value) => value.sales.isEmpty
              ? const EmptyState(
                  icon: Icons.point_of_sale_rounded,
                  title: 'Aucune vente cette semaine',
                  message: 'Enregistrez une vente en quelques gestes avec le bouton ci-dessous.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                  itemCount: value.sales.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final sale = value.sales[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(child: Text('${sale.quantity}×')),
                        title: Text(
                          formatMoney(sale.revenue),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${formatDay(sale.date)} • bénéfice ${formatMoney(sale.profit)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.undo_rounded),
                          tooltip: 'Annuler la vente',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Annuler la vente ?'),
                                content: const Text(
                                  'Les quantités seront remises dans leurs lots d’origine.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Non'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Annuler la vente'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            final result = await ref.read(cancelSaleProvider)(
                              sale.id,
                            );
                            if (!context.mounted) return;
                            result.fold(
                              (f) =>
                                  showMessage(context, f.message, error: true),
                              (_) {
                                ref.invalidate(catalogProvider(shop.id));
                                ref.invalidate(globalCatalogProvider);
                                ref.invalidate(
                                  weeklyReportProvider((
                                    shopId: shop.id,
                                    anchor: DateTime.now(),
                                  )),
                                );
                                ref.invalidate(dashboardProvider);
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        Positioned(
          right: 20,
          bottom: 22,
          child: FloatingActionButton.extended(
            heroTag: 'sale-${shop.id}',
            onPressed: () async {
              final items = catalog.value ?? const <CatalogItem>[];
              if (items
                  .where((item) => item.variant.stockQuantity > 0)
                  .isEmpty) {
                showMessage(context, 'Ajoutez d’abord du stock.', error: true);
                return;
              }
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => SaleFormSheet(shop: shop, items: items),
              );
            },
            icon: const Icon(Icons.point_of_sale),
            label: const Text('Vendre'),
          ),
        ),
      ],
    );
  }
}

class _ReportTab extends ConsumerWidget {
  const _ReportTab({required this.shop});
  final Shop shop;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(
      weeklyReportProvider((shopId: shop.id, anchor: DateTime.now())),
    );
    return report.when(
      loading: () => const LoadingCards(),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(
          weeklyReportProvider((shopId: shop.id, anchor: DateTime.now())),
        ),
      ),
      data: (value) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Chiffre d’affaires',
                  value: formatMoney(value.revenue),
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Bénéfice',
                  value: formatMoney(value.profit),
                  icon: Icons.trending_up_rounded,
                  positive: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Paires vendues',
                  value: '${value.pairsSold}',
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Stock restant',
                  value: '${value.remainingStock}',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
            ],
          ),
          if (shop.compensationType == CompensationType.percentage) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(
                  'Part de ${shop.sellerName.isEmpty ? 'la vendeuse' : shop.sellerName}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${shop.percentageRate}% sur ${shop.compensationBasis == CompensationBasis.revenue ? 'le chiffre d’affaires' : 'le bénéfice'}',
                ),
                trailing: Text(
                  formatMoney(value.sellerShare),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => context.go('/reports'),
            icon: const Icon(Icons.fullscreen_rounded),
            label: const Text('Ouvrir les rapports détaillés'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.positive = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool positive;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: positive
                ? AppColors.profit
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class ProductFormSheet extends ConsumerStatefulWidget {
  const ProductFormSheet({super.key, required this.shopId});
  final String shopId;
  @override
  ConsumerState<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<ProductFormSheet> {
  final _name = TextEditingController();
  final _category = TextEditingController(text: 'Général');
  final _size = TextEditingController();
  final _color = TextEditingController();
  String? _photo;
  bool _saving = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        _size.text.trim().isEmpty ||
        _color.text.trim().isEmpty) {
      showMessage(
        context,
        'Nom, pointure et couleur sont obligatoires.',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    final existing =
        ref.read(categoriesProvider(widget.shopId)).value ?? const <Category>[];
    var category = existing
        .where(
          (item) =>
              item.name.toLowerCase() == _category.text.trim().toLowerCase(),
        )
        .firstOrNull;
    if (category == null) {
      category = Category(
        id: const Uuid().v4(),
        shopId: widget.shopId,
        name: _category.text.trim(),
      );
      final categoryResult = await ref.read(saveCategoryProvider)(category);
      final failed = categoryResult.fold((f) => f, (_) => null);
      if (failed != null && mounted) {
        setState(() => _saving = false);
        showMessage(context, failed.message, error: true);
        return;
      }
    }
    final product = Product(
      id: const Uuid().v4(),
      shopId: widget.shopId,
      categoryId: category.id,
      name: _name.text.trim(),
      photoPath: _photo,
    );
    final variant = ProductVariant(
      id: const Uuid().v4(),
      productId: product.id,
      size: _size.text.trim(),
      color: _color.text.trim(),
      stockQuantity: 0,
    );
    final result = await ref.read(saveProductProvider)(product, variant);
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold((f) => showMessage(context, f.message, error: true), (_) {
      ref.invalidate(catalogProvider(widget.shopId));
      ref.invalidate(globalCatalogProvider);
      ref.invalidate(categoriesProvider(widget.shopId));
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nouvel article',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              InkWell(
                onTap: () async {
                  final result = await ref.read(pickPhotoProvider)();
                  result.fold(
                    (f) => showMessage(context, f.message, error: true),
                    (path) => setState(() => _photo = path),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _photo == null
                      ? const Icon(Icons.add_a_photo_outlined)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(File(_photo!), fit: BoxFit.cover),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nom de l’article',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _category,
            decoration: const InputDecoration(labelText: 'Catégorie'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _size,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pointure'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _color,
                  decoration: const InputDecoration(labelText: 'Couleur'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Enregistrement…' : 'Créer l’article'),
            ),
          ),
        ],
      ),
    ),
  );
}

class StockFormSheet extends ConsumerStatefulWidget {
  const StockFormSheet({super.key, required this.shopId, required this.item});
  final String shopId;
  final CatalogItem item;
  @override
  ConsumerState<StockFormSheet> createState() => _StockFormSheetState();
}

class _StockFormSheetState extends ConsumerState<StockFormSheet> {
  final _quantity = TextEditingController();
  final _purchase = TextEditingController();
  final _transport = TextEditingController(text: '0');
  final _sale = TextEditingController();
  bool _saving = false;
  int get q => int.tryParse(_quantity.text) ?? 0;
  int get purchase => int.tryParse(_purchase.text.replaceAll(' ', '')) ?? 0;
  int get transport => int.tryParse(_transport.text.replaceAll(' ', '')) ?? 0;
  int get sale => int.tryParse(_sale.text.replaceAll(' ', '')) ?? 0;

  Future<void> _save() async {
    if (q <= 0 || purchase < 0 || sale < 0) {
      return showMessage(
        context,
        'Vérifiez les montants et la quantité.',
        error: true,
      );
    }
    setState(() => _saving = true);
    final entry = StockEntry(
      id: const Uuid().v4(),
      shopId: widget.shopId,
      productId: widget.item.product.id,
      variantId: widget.item.variant.id,
      date: DateTime.now(),
      quantity: q,
      remainingQuantity: q,
      unitPurchasePrice: purchase,
      transportCost: transport,
      plannedUnitSalePrice: sale,
    );
    final result = await ref.read(addStockProvider)(entry);
    if (!mounted) return;
    result.fold(
      (f) {
        setState(() => _saving = false);
        showMessage(context, f.message, error: true);
      },
      (_) {
        ref.invalidate(catalogProvider(widget.shopId));
        ref.invalidate(globalCatalogProvider);
        ref.invalidate(dashboardProvider);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final calculator = const StockCostCalculator();
    final unitCost = q <= 0
        ? 0
        : calculator.unitLandedCost(
            quantity: q,
            unitPurchasePrice: purchase,
            transportCost: transport,
          );
    final profit = q <= 0 ? 0 : (sale - unitCost) * q;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Entrée de stock',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              '${widget.item.product.name} • ${widget.item.variant.size} • ${widget.item.variant.color}',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _quantity,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantité'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _purchase,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prix d’achat unitaire',
                suffixText: 'FCFA',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _transport,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Transport du lot',
                suffixText: 'FCFA',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sale,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prix de vente prévu',
                suffixText: 'FCFA',
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coût unitaire',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            formatMoney(unitCost),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bénéfice du lot',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            formatMoney(profit),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: profit >= 0
                                  ? AppColors.profit
                                  : AppColors.loss,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Enregistrement…' : 'Ajouter au stock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SaleFormSheet extends ConsumerStatefulWidget {
  const SaleFormSheet({super.key, required this.shop, required this.items});
  final Shop shop;
  final List<CatalogItem> items;
  @override
  ConsumerState<SaleFormSheet> createState() => _SaleFormSheetState();
}

class _SaleFormSheetState extends ConsumerState<SaleFormSheet> {
  late CatalogItem _item = widget.items.firstWhere(
    (item) => item.variant.stockQuantity > 0,
  );
  final _quantity = TextEditingController(text: '1');
  late final TextEditingController _price = TextEditingController(
    text: '${_item.suggestedUnitSalePrice}',
  );
  bool _saving = false;

  Future<void> _save() async {
    final quantity = int.tryParse(_quantity.text) ?? 0;
    final price = int.tryParse(_price.text.replaceAll(' ', '')) ?? -1;
    setState(() => _saving = true);
    final result = await ref.read(recordSaleProvider)(
      id: const Uuid().v4(),
      shopId: widget.shop.id,
      variantId: _item.variant.id,
      quantity: quantity,
      unitSalePrice: price,
      date: DateTime.now(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold((f) => showMessage(context, f.message, error: true), (_) {
      ref.invalidate(catalogProvider(widget.shop.id));
      ref.invalidate(globalCatalogProvider);
      ref.invalidate(
        weeklyReportProvider((shopId: widget.shop.id, anchor: DateTime.now())),
      );
      ref.invalidate(dashboardProvider);
      Navigator.pop(context);
      showMessage(context, 'Vente enregistrée.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.items
        .where((item) => item.variant.stockQuantity > 0)
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vente rapide',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<CatalogItem>(
              initialValue: _item,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Article et variante',
              ),
              items: available
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        '${item.product.name} • ${item.variant.size} • ${item.variant.color} (${item.variant.stockQuantity})',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (item) => setState(() {
                _item = item!;
                _price.text = '${item.suggestedUnitSalePrice}';
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantité',
                      helperText: 'Max. ${_item.variant.stockQuantity}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Prix unitaire',
                      suffixText: 'FCFA',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_saving ? 'Validation…' : 'Valider la vente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
