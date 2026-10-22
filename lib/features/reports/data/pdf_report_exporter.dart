import 'dart:io';

import 'package:flutter/services.dart';
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
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final document = pw.Document(
      title: sellerOnly
          ? 'Rapport vendeuse — $shopName'
          : 'Rapport boutique — $shopName',
      author: 'PeMS Store',
    );
    final ink = PdfColor.fromHex('#30262B');
    final rose = PdfColor.fromHex('#E8B7C6');
    final blush = PdfColor.fromHex('#F9EDF1');
    final muted = PdfColor.fromHex('#766B70');
    final paper = PdfColor.fromHex('#FBF8F9');
    document.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        margin: const pw.EdgeInsets.fromLTRB(34, 32, 34, 30),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: rose, width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'PeMS STORE',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 1.2,
                  color: ink,
                ),
              ),
              pw.Text(
                sellerOnly ? 'RAPPORT VENDEUSE' : 'RAPPORT BOUTIQUE',
                style: pw.TextStyle(
                  color: muted,
                  fontSize: 9,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 24),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              color: ink,
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  sellerOnly ? 'SYNTHÈSE VENDEUSE' : 'SYNTHÈSE COMMERCIALE',
                  style: pw.TextStyle(
                    color: rose,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.3,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  shopName,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Période du ${formatDay(report.start)} au ${formatDay(report.endExclusive.subtract(const Duration(days: 1)))}',
                  style: pw.TextStyle(color: blush, fontSize: 11),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 22),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metric('PAIRES VENDUES', '${report.pairsSold}', blush, ink),
              _metric(
                "CHIFFRE D'AFFAIRES",
                formatMoney(report.revenue),
                blush,
                ink,
              ),
              if (!sellerOnly)
                _metric(
                  'COÛT DE REVIENT',
                  formatMoney(report.landedCost),
                  paper,
                  ink,
                ),
              if (!sellerOnly)
                _metric('BÉNÉFICE', formatMoney(report.profit), rose, ink),
              if (sellerOnly)
                _metric(
                  'MONTANT DÛ',
                  formatMoney(report.sellerShare),
                  rose,
                  ink,
                ),
            ],
          ),
          pw.SizedBox(height: 26),
          if (!sellerOnly) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: paper,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'STOCK RESTANT',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: muted,
                    ),
                  ),
                  pw.Text(
                    '${report.remainingStock} paires  ·  ${formatMoney(report.remainingStockValue)}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 26),
          ],
          pw.Text(
            'Détail des ventes',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: ink,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '${report.salesCount} vente${report.salesCount > 1 ? 's' : ''} validée${report.salesCount > 1 ? 's' : ''} sur la période',
            style: pw.TextStyle(fontSize: 10, color: muted),
          ),
          pw.SizedBox(height: 12),
          if (report.sales.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: paper,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                'Aucune vente validée pour cette période.',
                style: pw.TextStyle(color: muted),
              ),
            )
          else
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
              headerDecoration: pw.BoxDecoration(color: ink),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: pw.TextStyle(fontSize: 9, color: ink),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: pw.BoxDecoration(color: paper),
              border: null,
            ),
        ],
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: blush)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'PeMS Store  ·  $shopName',
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
            ],
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

  pw.Widget _metric(
    String label,
    String value,
    PdfColor background,
    PdfColor foreground,
  ) => pw.Container(
    width: 245,
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      color: background,
      borderRadius: pw.BorderRadius.circular(11),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            color: foreground,
            letterSpacing: .5,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: foreground,
            fontSize: 17,
            fontWeight: pw.FontWeight.bold,
          ),
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
