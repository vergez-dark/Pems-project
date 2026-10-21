import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/shop.dart';

class ShopsPage extends ConsumerWidget {
  const ShopsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shops = ref.watch(shopsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Boutiques')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const ShopFormDialog(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: shops.when(
        loading: () => const LoadingCards(),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(shopsProvider),
        ),
        data: (items) => items.isEmpty
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
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final shop = items[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push('/shops/${shop.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                child: Text(
                                  shop.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shop.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      shop.sellerName.isEmpty
                                          ? 'Vendeuse non renseignée'
                                          : shop.sellerName,
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        shop.compensationType ==
                                                CompensationType.none
                                            ? 'Sans commission'
                                            : '${shop.percentageRate}% sur ${shop.compensationBasis == CompensationBasis.revenue ? 'CA' : 'bénéfice'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
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
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final shop = Shop(
      id: widget.shop?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      sellerName: _seller.text.trim(),
      whatsapp: _phone.text.trim(),
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
              DropdownButtonFormField<CompensationType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Rémunération'),
                items: const [
                  DropdownMenuItem(
                    value: CompensationType.none,
                    child: Text('Sans pourcentage'),
                  ),
                  DropdownMenuItem(
                    value: CompensationType.percentage,
                    child: Text('À pourcentage'),
                  ),
                ],
                onChanged: (value) => setState(() => _type = value!),
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
