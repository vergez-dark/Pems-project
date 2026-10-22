import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/pems_components.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/sale.dart';

class SaleDetailsSheet extends ConsumerWidget {
  const SaleDetailsSheet({super.key, required this.summary});

  final SaleSummary summary;

  static Future<void> show(BuildContext context, SaleSummary summary) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => SaleDetailsSheet(summary: summary),
      );

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler cette vente ?'),
        content: const Text(
          'La vente restera dans l’historique et ses quantités seront remises dans les lots de stock d’origine.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Conserver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Annuler la vente'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref.read(cancelSaleProvider)(summary.sale.id);
    if (!context.mounted) return;
    result.fold(
      (failure) => showMessage(context, failure.message, error: true),
      (_) {
        ref.invalidate(salesHistoryProvider(null));
        ref.invalidate(salesHistoryProvider(summary.sale.shopId));
        ref.invalidate(catalogProvider(summary.sale.shopId));
        ref.invalidate(globalCatalogProvider);
        ref.invalidate(dashboardProvider);
        ref.invalidate(
          weeklyReportProvider(
            ReportQuery(shopId: summary.sale.shopId, anchor: DateTime.now()),
          ),
        );
        showMessage(context, 'Vente annulée. Le stock a été rétabli.');
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = summary.sale;
    final cancelled = sale.status == SaleStatus.cancelled;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .76,
      minChildSize: .55,
      maxChildSize: .94,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: cancelled
                    ? Theme.of(context).colorScheme.errorContainer
                    : AppColors.roseLight,
                child: Icon(
                  cancelled
                      ? Icons.cancel_outlined
                      : Icons.receipt_long_rounded,
                  color: cancelled ? null : AppColors.roseDark,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Détails de la vente',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      DateFormat(
                        "EEEE d MMMM yyyy 'à' HH:mm",
                        'fr_FR',
                      ).format(sale.date),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PemsPill(
                label: cancelled ? 'Annulée' : 'Validée',
                backgroundColor: (cancelled ? AppColors.loss : AppColors.profit)
                    .withValues(alpha: .14),
                foregroundColor: cancelled ? AppColors.loss : AppColors.profit,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Text(
                  formatMoney(sale.revenue),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Montant total encaissé'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _DetailsSection(
            title: 'Article',
            icon: Icons.checkroom_outlined,
            rows: [
              ('Produit', summary.productName),
              ('Boutique', summary.shopName),
              ('Pointure', summary.size),
              ('Couleur', summary.color),
              (
                'Quantité',
                '${sale.quantity} paire${sale.quantity > 1 ? 's' : ''}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailsSection(
            title: 'Paiement et rentabilité',
            icon: Icons.payments_outlined,
            rows: [
              ('Mode de paiement', _paymentLabel(sale.paymentMethod)),
              ('Prix unitaire', formatMoney(sale.actualUnitSalePrice)),
              (
                'Coût de revient unitaire',
                formatMoney(sale.frozenUnitLandedCost),
              ),
              ('Coût total', formatMoney(sale.landedCost)),
              ('Bénéfice', formatMoney(sale.profit)),
            ],
          ),
          const SizedBox(height: 12),
          if (!cancelled) ...[
            OutlinedButton.icon(
              onPressed: () => _cancel(context, ref),
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Annuler cette vente'),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Référence : ${sale.id}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _paymentLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'Espèces',
  PaymentMethod.mobileMoney => 'Mobile Money',
  PaymentMethod.card => 'Carte',
};
