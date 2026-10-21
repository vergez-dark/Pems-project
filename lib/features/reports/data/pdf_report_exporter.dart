import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/result.dart';
import '../../../core/utils/formatters.dart';
import '../domain/report_repository.dart';
import '../domain/weekly_report.dart';

class PdfReportExporter implements ReportExporter {
  const PdfReportExporter();

  Future<File> _build(
    WeeklyReport report,
    String shopName,
    bool sellerOnly,
  ) async {
    final document = pw.Document(
      title: sellerOnly
          ? 'Rapport vendeuse — $shopName'
          : 'Rapport boutique — $shopName',
      author: 'PeMS Store',
    );
    final green = PdfColor.fromHex('#12372A');
    final accent = PdfColor.fromHex('#D9E76C');
    document.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'PASORA',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 18,
                color: green,
              ),
            ),
            pw.Text(sellerOnly ? 'Bilan vendeuse' : 'Bilan boutique'),
          ],
        ),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: green,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  shopName,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Du ${formatDay(report.start)} au ${formatDay(report.endExclusive.subtract(const Duration(days: 1)))}',
                  style: const pw.TextStyle(color: PdfColors.white),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric('Paires vendues', '${report.pairsSold}', accent),
              _metric(
                'Chiffre d’affaires',
                formatMoney(report.revenue),
                accent,
              ),
              if (!sellerOnly)
                _metric(
                  'Coût de revient',
                  formatMoney(report.landedCost),
                  accent,
                ),
              if (!sellerOnly)
                _metric('Bénéfice', formatMoney(report.profit), accent),
              if (sellerOnly)
                _metric('Montant dû', formatMoney(report.sellerShare), accent),
            ],
          ),
          pw.SizedBox(height: 24),
          if (!sellerOnly) ...[
            pw.Text(
              'Stock restant',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '${report.remainingStock} paires • valeur ${formatMoney(report.remainingStockValue)}',
            ),
            pw.SizedBox(height: 20),
          ],
          pw.Text(
            'Détail des ventes',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: sellerOnly
                ? ['Date', 'Qté', 'Vente']
                : ['Date', 'Qté', 'Vente', 'Coût', 'Bénéfice'],
            data: report.sales
                .map(
                  (sale) => sellerOnly
                      ? [
                          formatDay(sale.date),
                          sale.quantity,
                          formatMoney(sale.revenue),
                        ]
                      : [
                          formatDay(sale.date),
                          sale.quantity,
                          formatMoney(sale.revenue),
                          formatMoney(sale.landedCost),
                          formatMoney(sale.profit),
                        ],
                )
                .toList(),
            headerDecoration: pw.BoxDecoration(color: green),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            cellPadding: const pw.EdgeInsets.all(7),
          ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'PeMS Store • page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ),
    );
    final directory = await getTemporaryDirectory();
    final suffix = sellerOnly ? 'vendeuse' : 'boutique';
    final file = File(
      p.join(
        directory.path,
        'pems-store-$suffix-${report.start.toIso8601String().substring(0, 10)}.pdf',
      ),
    );
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  pw.Widget _metric(String label, String value, PdfColor color) => pw.Container(
    width: 235,
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  @override
  Future<Result<String>> exportPdf(
    WeeklyReport report,
    String shopName, {
    bool sellerOnly = false,
  }) async {
    try {
      return Success((await _build(report, shopName, sellerOnly)).path);
    } catch (error) {
      return Failure(AppFailure('Création du PDF impossible.', cause: error));
    }
  }

  @override
  Future<Result<void>> share(
    WeeklyReport report,
    String shopName,
    String phone, {
    bool sellerOnly = false,
  }) async {
    try {
      final file = await _build(report, shopName, sellerOnly);
      final amount = sellerOnly ? report.sellerShare : report.profit;
      final message =
          'Bilan PeMS Store — $shopName\n${report.pairsSold} paires vendues • ${formatMoney(amount)}\nDu ${formatDay(report.start)} au ${formatDay(report.endExclusive.subtract(const Duration(days: 1)))}';
      await SharePlus.instance.share(
        ShareParams(text: message, files: [XFile(file.path)]),
      );
      return const Success(null);
    } catch (error) {
      return Failure(AppFailure('Partage impossible.', cause: error));
    }
  }

  @override
  Future<Result<String>> exportImage(
    WeeklyReport report,
    String shopName, {
    bool sellerOnly = false,
  }) async {
    try {
      final pdf = await _build(report, shopName, sellerOnly);
      final page = await Printing.raster(
        await pdf.readAsBytes(),
        pages: const [0],
        dpi: 144,
      ).first;
      final image = File('${pdf.path.substring(0, pdf.path.length - 4)}.png');
      await image.writeAsBytes(await page.toPng(), flush: true);
      return Success(image.path);
    } catch (error) {
      return Failure(
        AppFailure('Création de l’image impossible.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> sendSummaryToWhatsApp(
    WeeklyReport report,
    String shopName,
    String phone, {
    bool sellerOnly = false,
  }) async {
    try {
      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) {
        return const Failure(
          AppFailure('Ajoutez le numéro WhatsApp dans la boutique.'),
        );
      }
      final amount = sellerOnly ? report.sellerShare : report.profit;
      final text = Uri.encodeComponent(
        'Bilan PeMS Store — $shopName\n${report.pairsSold} paires vendues • ${formatMoney(amount)}\nDu ${formatDay(report.start)} au ${formatDay(report.endExclusive.subtract(const Duration(days: 1)))}',
      );
      final opened = await launchUrl(
        Uri.parse('https://wa.me/$digits?text=$text'),
        mode: LaunchMode.externalApplication,
      );
      return opened
          ? const Success(null)
          : const Failure(AppFailure('WhatsApp n’a pas pu être ouvert.'));
    } catch (error) {
      return Failure(
        AppFailure('Ouverture de WhatsApp impossible.', cause: error),
      );
    }
  }
}
