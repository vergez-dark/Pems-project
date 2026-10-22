import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pems_components.dart';
import '../../../core/widgets/state_views.dart';
import '../../catalog/presentation/photo_source_sheet.dart';
import '../domain/shop.dart';

class ShopsPage extends ConsumerStatefulWidget {
  const ShopsPage({super.key});

  @override
  ConsumerState<ShopsPage> createState() => _ShopsPageState();
}

class _ShopsPageState extends ConsumerState<ShopsPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shops = ref.watch(shopsProvider);
    return Scaffold(
      appBar: PemsBrandHeader(
        section: 'Boutiques',
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil et réglages',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: shops.when(
        loading: () => const LoadingCards(),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(shopsProvider),
        ),
        data: (items) {
          final query = _search.text.trim().toLowerCase();
          final filtered = items.where((shop) {
            return query.isEmpty ||
                shop.name.toLowerCase().contains(query) ||
                shop.sellerName.toLowerCase().contains(query) ||
                shop.whatsapp.contains(query);
          }).toList();
          return items.isEmpty
              ? EmptyState(
                  icon: Icons.storefront_rounded,
                  title: 'Aucune boutique',
                  message: 'Une boutique représente une vendeuse ou un point de vente.',
                  action: FilledButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const ShopFormDialog(),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Créer la première'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(shopsProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RÉSEAU COMMERCIAL',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 11,
                                    letterSpacing: .8,
                                  ),
                                ),
                                Text(
                                  'Réseau Boutiques',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                Text(
                                  'Supervision commerciale et inventaire',
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
                          FilledButton.icon(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => const ShopFormDialog(),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Nouvelle'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: .45),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(Icons.storefront_outlined),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _NetworkMetric(
                                  label: 'ACTIVITÉ GLOBALE',
                                  value:
                                      '${items.length} point${items.length > 1 ? 's' : ''} de vente',
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 38,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _NetworkMetric(
                                  label: 'STATUT',
                                  value:
                                      '${items.where((shop) => !shop.isArchived).length} active${items.length > 1 ? 's' : ''}',
                                  accent: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Rechercher boutique, vendeuse…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        const EmptyState(
                          icon: Icons.search_off,
                          title: 'Aucun résultat',
                          message: 'Modifiez votre recherche.',
                        )
                      else
                        ...filtered.map(
                          (shop) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ShopNetworkCard(shop: shop),
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

class _NetworkMetric extends StatelessWidget {
  const _NetworkMetric({required this.label, required this.value, this.accent});
  final String label;
  final String value;
  final Color? accent;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 9,
          letterSpacing: .5,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: accent),
      ),
    ],
  );
}

class _ShopNetworkCard extends StatelessWidget {
  const _ShopNetworkCard({required this.shop});
  final Shop shop;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/shops/${shop.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                PemsPhoto(
                  photoPath: shop.photoPath,
                  width: 52,
                  height: 52,
                  borderRadius: 14,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PemsPill(
                  icon: Icons.circle,
                  label: shop.isArchived ? 'Archivée' : 'Active',
                  backgroundColor:
                      (shop.isArchived ? AppColors.muted : AppColors.profit)
                          .withValues(alpha: .14),
                  foregroundColor: shop.isArchived
                      ? AppColors.muted
                      : AppColors.profit,
                ),
                IconButton(
                  tooltip: 'Ouvrir ${shop.name}',
                  onPressed: () => context.push('/shops/${shop.id}'),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer
                    .withValues(alpha: .16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _NetworkMetric(
                      label: 'VENDEUSE',
                      value: shop.sellerName.isEmpty
                          ? 'Non renseignée'
                          : shop.sellerName,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NetworkMetric(
                      label: 'WHATSAPP',
                      value: shop.whatsapp.isEmpty
                          ? 'Non renseigné'
                          : '+${shop.whatsapp}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NetworkMetric(
                    label: 'COMMISSION',
                    value: shop.compensationType == CompensationType.none
                        ? 'Sans commission'
                        : '${shop.percentageRate}% • ${shop.compensationBasis == CompensationBasis.revenue ? 'CA' : 'bénéfice'}',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.push('/shops/${shop.id}'),
                  icon: const Icon(Icons.point_of_sale_outlined, size: 18),
                  label: const Text('Gérer'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ShopFormDialog extends ConsumerStatefulWidget {
  const ShopFormDialog({super.key, this.shop});
  final Shop? shop;
  @override
  ConsumerState<ShopFormDialog> createState() => _ShopFormDialogState();
}

class _ShopFormDialogState extends ConsumerState<ShopFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.shop?.name ?? '',
  );
  late final TextEditingController _seller = TextEditingController(
    text: widget.shop?.sellerName ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.shop?.whatsapp ?? '',
  );
  late final TextEditingController _rate = TextEditingController(
    text: '${widget.shop?.percentageRate ?? 0}',
  );
  late CompensationType _type =
      widget.shop?.compensationType ?? CompensationType.none;
  late CompensationBasis _basis =
      widget.shop?.compensationBasis ?? CompensationBasis.profit;
  late String? _photo = widget.shop?.photoPath;
  bool _saving = false;
  bool _pickingPhoto = false;

  Future<void> _pickPhoto() async {
    final source = await showPemsPhotoSourceSheet(context);
    if (!mounted || source == null) return;
    setState(() => _pickingPhoto = true);
    final result = await ref.read(pickPhotoProvider)(source: source);
    if (!mounted) return;
    setState(() => _pickingPhoto = false);
    result.fold(
      (failure) => showMessage(context, failure.message, error: true),
      (path) {
        if (path != null) setState(() => _photo = path);
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final shop = Shop(
      id: widget.shop?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      sellerName: _seller.text.trim(),
      whatsapp: _phone.text.trim(),
      photoPath: _photo,
      compensationType: _type,
      percentageRate: _type == CompensationType.none
          ? 0
          : int.parse(_rate.text),
      compensationBasis: _basis,
      createdAt: widget.shop?.createdAt ?? now,
      updatedAt: now,
    );
    final result = await ref.read(saveShopProvider)(shop);
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (failure) => showMessage(context, failure.message, error: true),
      (_) {
        ref.invalidate(shopsProvider);
        ref.invalidate(dashboardProvider);
        ref.invalidate(globalCatalogProvider);
        showMessage(
          context,
          widget.shop == null
              ? 'Boutique créée avec succès.'
              : 'Boutique mise à jour.',
        );
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.shop == null ? 'Nouvelle boutique' : 'Modifier la boutique',
    ),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PemsPhoto(
                        photoPath: _photo,
                        width: 86,
                        height: 86,
                        borderRadius: 20,
                      ),
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: IconButton.filled(
                          onPressed: _pickingPhoto ? null : _pickPhoto,
                          tooltip: 'Choisir une photo',
                          icon: _pickingPhoto
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.photo_camera_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Photo de la boutique',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Facultative • une illustration est affichée par défaut.',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        if (_photo != null)
                          TextButton.icon(
                            onPressed: () => setState(() => _photo = null),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Retirer'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nom de la boutique',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _seller,
                decoration: const InputDecoration(
                  labelText: 'Nom de la vendeuse',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp',
                  prefixText: '+',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Rémunération',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<CompensationType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: CompensationType.none,
                      label: Text('Sans %'),
                      icon: Icon(Icons.remove_circle_outline),
                    ),
                    ButtonSegment(
                      value: CompensationType.percentage,
                      label: Text('Pourcentage'),
                      icon: Icon(Icons.percent_rounded),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) =>
                      setState(() => _type = selection.first),
                ),
              ),
              if (_type == CompensationType.percentage) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Taux',
                    suffixText: '%',
                  ),
                  validator: (v) {
                    final value = int.tryParse(v ?? '');
                    return value == null || value < 0 || value > 100
                        ? 'Entre 0 et 100'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                SegmentedButton<CompensationBasis>(
                  segments: const [
                    ButtonSegment(
                      value: CompensationBasis.revenue,
                      label: Text('Chiffre d’affaires'),
                    ),
                    ButtonSegment(
                      value: CompensationBasis.profit,
                      label: Text('Bénéfice'),
                    ),
                  ],
                  selected: {_basis},
                  onSelectionChanged: (value) =>
                      setState(() => _basis = value.first),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Enregistrer'),
      ),
    ],
  );
}
