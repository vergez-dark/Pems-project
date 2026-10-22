import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/pems_components.dart';
import '../../../core/widgets/state_views.dart';
import '../../inventory/presentation/stock_details_sheet.dart';
import '../../shops/domain/shop.dart';
import '../../shops/presentation/shop_detail_page.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _search = TextEditingController();
  String? _shopId;
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Shop?> _chooseShop(List<Shop> shops) async {
    if (_shopId != null) {
      return shops.where((shop) => shop.id == _shopId).firstOrNull;
    }
    if (shops.length == 1) return shops.first;
    return showModalBottomSheet<Shop>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choisir une boutique',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            ...shops.map(
              (shop) => ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.storefront_outlined),
                ),
                title: Text(shop.name),
                subtitle: Text(
                  shop.sellerName.isEmpty ? 'Aucune vendeuse' : shop.sellerName,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, shop),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(globalCatalogProvider);
    final shops = ref.watch(shopsProvider).value ?? const <Shop>[];
    return Scaffold(
      appBar: PemsBrandHeader(
        section: 'Stock',
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(globalCatalogProvider),
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: catalog.when(
        loading: () => const LoadingCards(),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(globalCatalogProvider),
        ),
        data: (records) {
          final categories =
              records.map((record) => record.item.categoryName).toSet().toList()
                ..sort();
          final query = _search.text.trim().toLowerCase();
          final filtered = records.where((record) {
            final item = record.item;
            final matchesShop = _shopId == null || record.shop.id == _shopId;
            final matchesCategory =
                _category == null || item.categoryName == _category;
            final matchesSearch =
                query.isEmpty ||
                item.product.name.toLowerCase().contains(query) ||
                item.categoryName.toLowerCase().contains(query) ||
                item.variant.size.toLowerCase().contains(query) ||
                item.variant.color.toLowerCase().contains(query);
            return matchesShop && matchesCategory && matchesSearch;
          }).toList();
          final totalStock = records.fold<int>(
            0,
            (sum, record) => sum + record.item.variant.stockQuantity,
          );
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(globalCatalogProvider),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  sliver: SliverList.list(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'INVENTAIRE GLOBAL',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 11,
                                    letterSpacing: .8,
                                  ),
                                ),
                                Text(
                                  'Catalogue & Stocks',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                              ],
                            ),
                          ),
                          PemsPill(
                            icon: Icons.circle,
                            label:
                                '${records.length} références • $totalStock paires',
                            foregroundColor: AppColors.roseDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Rechercher modèle, pointure, couleur…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? const Icon(Icons.qr_code_scanner_rounded)
                              : IconButton(
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      PemsDropdownField<String?>(
                        value: _shopId,
                        label: 'Filtrer par point de vente',
                        leadingIcon: Icons.storefront_outlined,
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'Toutes les boutiques (${shops.length})',
                            ),
                          ),
                          ...shops.map(
                            (shop) => DropdownMenuItem<String?>(
                              value: shop.id,
                              child: Text(shop.name),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _shopId = value),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: shops.isEmpty
                                  ? null
                                  : () async {
                                      final shop = await _chooseShop(shops);
                                      if (shop == null || !context.mounted) {
                                        return;
                                      }
                                      final shopItems = records
                                          .where(
                                            (record) =>
                                                record.shop.id == shop.id,
                                          )
                                          .toList();
                                      if (shopItems.isEmpty) {
                                        showMessage(
                                          context,
                                          'Ajoutez d’abord un article.',
                                          error: true,
                                        );
                                        return;
                                      }
                                      final record = shopItems.first;
                                      await showModalBottomSheet<void>(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
                                        builder: (_) => StockFormSheet(
                                          shopId: shop.id,
                                          item: record.item,
                                        ),
                                      );
                                      ref.invalidate(globalCatalogProvider);
                                    },
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Entrée stock'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: shops.isEmpty
                                  ? null
                                  : () async {
                                      final shop = await _chooseShop(shops);
                                      if (shop == null || !context.mounted) {
                                        return;
                                      }
                                      await context.push<void>(
                                        '/shops/${shop.id}/products/new',
                                      );
                                      ref.invalidate(globalCatalogProvider);
                                    },
                              icon: const Icon(Icons.library_add_outlined),
                              label: const Text('Article'),
                            ),
                          ),
                        ],
                      ),
                      if (categories.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ChoiceChip(
                                label: Text('Tous (${records.length})'),
                                selected: _category == null,
                                onSelected: (_) =>
                                    setState(() => _category = null),
                              ),
                              const SizedBox(width: 8),
                              ...categories.map(
                                (category) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(category),
                                    selected: _category == category,
                                    onSelected: (_) =>
                                        setState(() => _category = category),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (records.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Catalogue vide',
                      message: 'Créez une boutique puis ajoutez votre premier article.',
                      action: shops.isEmpty
                          ? FilledButton(
                              onPressed: () => context.go('/shops'),
                              child: const Text('Créer une boutique'),
                            )
                          : null,
                    ),
                  )
                else if (filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucun article trouvé',
                      message: 'Modifiez la recherche ou les filtres.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _CatalogCard(record: filtered[index]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CatalogCard extends ConsumerWidget {
  const _CatalogCard({required this.record});
  final GlobalCatalogItem record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = record.item;
    final stock = item.variant.stockQuantity;
    final threshold = ref.watch(settingsProvider).value?.lowStockThreshold ?? 3;
    final color = stockColor(stock, threshold);
    final path = item.product.photoPath;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => StockDetailsSheet.show(
          context,
          shop: record.shop,
          item: item,
          onAddStock: () {
            Future<void>.delayed(const Duration(milliseconds: 220), () async {
              if (!context.mounted) return;
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) =>
                    StockFormSheet(shopId: record.shop.id, item: item),
              );
              ref.invalidate(globalCatalogProvider);
              ref.invalidate(stockEntriesProvider(item.variant.id));
            });
          },
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: path != null && File(path).existsSync()
                        ? Image.file(
                            File(path),
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 88,
                            height: 88,
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: .45),
                            child: const Icon(
                              Icons.checkroom_rounded,
                              size: 38,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.categoryName.toUpperCase(),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 10,
                                  letterSpacing: .6,
                                ),
                              ),
                            ),
                            PemsPill(
                              label: stock == 0
                                  ? 'Rupture'
                                  : stock <= threshold
                                  ? 'Stock faible'
                                  : 'En stock',
                              backgroundColor: color.withValues(alpha: .14),
                              foregroundColor: color,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (item.suggestedUnitSalePrice > 0) ...[
                          const SizedBox(height: 5),
                          Text(
                            formatMoney(item.suggestedUnitSalePrice),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          record.shop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer
                      .withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pointure ${item.variant.size} • ${item.variant.color}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '$stock paire${stock > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stock <= threshold
                          ? 'Réapprovisionnement conseillé'
                          : 'Stock disponible',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) =>
                            StockFormSheet(shopId: record.shop.id, item: item),
                      );
                      ref.invalidate(globalCatalogProvider);
                    },
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: const Text('Entrée'),
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
