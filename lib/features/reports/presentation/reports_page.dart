import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/pems_components.dart';
import '../../shops/domain/shop.dart';
import '../domain/weekly_report.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String? _shopId;
  DateTime _anchor = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(shopsProvider);
    return Scaffold(
      appBar: const PemsBrandHeader(section: 'Rapports'),
      body: shopsAsync.when(
        loading: () => const LoadingCards(),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(shopsProvider),
        ),
        data: (shops) {
          if (shops.isEmpty) {
            return const EmptyState(
              icon: Icons.insights_rounded,
              title: 'Pas encore de rapport',
              message:
                  'Créez une boutique et enregistrez vos premières ventes.',
            );
          }
          final selectedId = shops.any((item) => item.id == _shopId)
              ? _shopId!
              : shops.first.id;
          final shop = shops.firstWhere((item) => item.id == selectedId);
          final report = ref.watch(
            weeklyReportProvider(
              ReportQuery(shopId: selectedId, anchor: _anchor),
            ),
          );
          final week = WeekRange.from(_anchor);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  children: [
                    PemsDropdownField<String>(
                      value: selectedId,
                      label: 'Boutique',
                      leadingIcon: Icons.storefront_outlined,
                      items: shops
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _shopId = value),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => setState(
                            () => _anchor = _anchor.subtract(
                              const Duration(days: 7),
                            ),
                          ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '${formatDay(week.start)} — ${formatDay(week.endExclusive.subtract(const Duration(days: 1)))}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => setState(
                            () =>
                                _anchor = _anchor.add(const Duration(days: 7)),
                          ),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: report.when(
                  loading: () => const LoadingCards(),
                  error: (error, _) => ErrorState(
                    error: error,
                    onRetry: () => ref.invalidate(
                      weeklyReportProvider(
                        ReportQuery(shopId: selectedId, anchor: _anchor),
                      ),
                    ),
                  ),
                  data: (value) => _ReportContent(shop: shop, report: value),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportContent extends ConsumerWidget {
  const _ReportContent({required this.shop, required this.report});
  final Shop shop;
  final WeeklyReport report;

  Future<void> _export(BuildContext context, WidgetRef ref, bool seller) async {
    final result = await ref.read(exportReportProvider)(
      report,
      shop.name,
      sellerOnly: seller,
    );
    if (!context.mounted) return;
    result.fold(
      (f) => showMessage(context, f.message, error: true),
      (path) => showMessage(context, 'PDF créé : $path'),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref, bool seller) async {
    final result = await ref.read(shareReportProvider)(
      report,
      shop.name,
      shop.whatsapp,
      sellerOnly: seller,
    );
    if (!context.mounted) return;
    result.fold(
      (f) => showMessage(context, f.message, error: true),
      (_) => showMessage(context, 'Feuille de partage ouverte.'),
    );
  }

  Future<void> _image(BuildContext context, WidgetRef ref, bool seller) async {
    final result = await ref.read(exportReportImageProvider)(
      report,
      shop.name,
      sellerOnly: seller,
    );
    if (!context.mounted) return;
    result.fold(
      (f) => showMessage(context, f.message, error: true),
      (path) => showMessage(context, 'Image créée : $path'),
    );
  }

  Future<void> _whatsApp(
    BuildContext context,
    WidgetRef ref,
    bool seller,
  ) async {
    final result = await ref.read(sendWhatsAppProvider)(
      report,
      shop.name,
      shop.whatsapp,
      sellerOnly: seller,
    );
    if (!context.mounted) return;
    result.fold((f) => showMessage(context, f.message, error: true), (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.forest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bénéfice net',
              style: TextStyle(color: Color(0xFFC6DDD1)),
            ),
            Text(
              formatMoney(report.profit),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _LightMetric(
                    label: 'Chiffre d’affaires',
                    value: formatMoney(report.revenue),
                  ),
                ),
                Expanded(
                  child: _LightMetric(
                    label: 'Coût de revient',
                    value: formatMoney(report.landedCost),
                  ),
                ),
                Expanded(
                  child: _LightMetric(
                    label: 'Paires',
                    value: '${report.pairsSold}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      if (shop.compensationType == CompensationType.percentage) ...[
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.lime,
                  foregroundColor: AppColors.forest,
                  child: Text('${shop.percentageRate}%'),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Part vendeuse',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Base : ${shop.compensationBasis == CompensationBasis.revenue ? 'chiffre d’affaires' : 'bénéfice'}',
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(report.sellerShare),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 22),
      Text(
        'Répartition par catégorie',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: report.categoryPerformance.every((item) => item.revenue == 0)
              ? const SizedBox(
                  height: 140,
                  child: Center(child: Text('Aucune vente sur cette période')),
                )
              : SizedBox(
                  height: 190,
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 34,
                            sectionsSpace: 3,
                            sections: report.categoryPerformance
                                .where((item) => item.revenue > 0)
                                .toList()
                                .asMap()
                                .entries
                                .map(
                                  (entry) => PieChartSectionData(
                                    value: entry.value.revenue.toDouble(),
                                    color: [
                                      AppColors.forest,
                                      AppColors.emerald,
                                      AppColors.lime,
                                      AppColors.warning,
                                      const Color(0xFF78909C),
                                    ][entry.key % 5],
                                    showTitle: false,
                                    radius: 32,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ListView(
                          shrinkWrap: true,
                          children: report.categoryPerformance
                              .where((item) => item.revenue > 0)
                              .take(5)
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.circle, size: 9),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text('${item.quantity}'),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        'Exporter et envoyer',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text(
                'Rapport général',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Ventes, coûts, bénéfice et stock'),
              trailing: Wrap(
                children: [
                  IconButton(
                    onPressed: () => _image(context, ref, false),
                    icon: const Icon(Icons.image_outlined),
                    tooltip: 'Créer une image',
                  ),
                  if (shop.whatsapp.isNotEmpty)
                    IconButton(
                      onPressed: () => _whatsApp(context, ref, false),
                      icon: const Icon(Icons.chat_outlined),
                      tooltip: 'Résumé WhatsApp',
                    ),
                  IconButton(
                    onPressed: () => _export(context, ref, false),
                    icon: const Icon(Icons.download_outlined),
                    tooltip: 'Créer le PDF',
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _share(context, ref, false),
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Partager',
                  ),
                ],
              ),
            ),
            if (shop.compensationType == CompensationType.percentage) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text(
                  'Rapport vendeuse',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Sans coût d’achat ni marge'),
                trailing: Wrap(
                  children: [
                    IconButton(
                      onPressed: () => _whatsApp(context, ref, true),
                      icon: const Icon(Icons.chat_outlined),
                      tooltip: 'Résumé WhatsApp',
                    ),
                    IconButton(
                      onPressed: () => _export(context, ref, true),
                      icon: const Icon(Icons.download_outlined),
                      tooltip: 'Créer le PDF',
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _share(context, ref, true),
                      icon: const Icon(Icons.send_outlined),
                      tooltip: 'Envoyer',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      Card(
        child: ListTile(
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(
            '${report.remainingStock} paires restantes',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            'Valeur du stock : ${formatMoney(report.remainingStockValue)}',
          ),
        ),
      ),
    ],
  );
}

class _LightMetric extends StatelessWidget {
  const _LightMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFFC6DDD1), fontSize: 9),
      ),
    ],
  );
}
