import '../../../core/error/result.dart';
import 'weekly_report.dart';

abstract interface class ReportRepository {
  Future<Result<WeeklyReport>> weekly(String shopId, DateTime anchor);
}

abstract interface class ReportExporter {
  Future<Result<String>> exportPdf(
    WeeklyReport report,
    String shopName, {
    bool sellerOnly = false,
  });
  Future<Result<void>> share(
    WeeklyReport report,
    String shopName,
    String phone, {
    bool sellerOnly = false,
  });
  Future<Result<String>> exportImage(
    WeeklyReport report,
    String shopName, {
    bool sellerOnly = false,
  });
  Future<Result<void>> sendSummaryToWhatsApp(
    WeeklyReport report,
    String shopName,
    String phone, {
    bool sellerOnly = false,
  });
}

class GetWeeklyReport {
  const GetWeeklyReport(this.repository);
  final ReportRepository repository;
  Future<Result<WeeklyReport>> call(String shopId, DateTime anchor) =>
      repository.weekly(shopId, anchor);
}

class ExportWeeklyReport {
  const ExportWeeklyReport(this.exporter);
  final ReportExporter exporter;
  Future<Result<String>> call(
    WeeklyReport report,
    String shopName, {
    bool sellerOnly = false,
  }) => exporter.exportPdf(report, shopName, sellerOnly: sellerOnly);
}

class ShareWeeklyReport {
  const ShareWeeklyReport(this.exporter);
  final ReportExporter exporter;
  Future<Result<void>> call(
    WeeklyReport report,
    String shopName,
    String phone, {
    bool sellerOnly = false,
  }) => exporter.share(report, shopName, phone, sellerOnly: sellerOnly);
}

class ExportWeeklyReportImage {
  const ExportWeeklyReportImage(this.exporter);
  final ReportExporter exporter;
  Future<Result<String>> call(
    WeeklyReport report,
    String shopName, {
    bool sellerOnly = false,
  }) => exporter.exportImage(report, shopName, sellerOnly: sellerOnly);
}

class SendReportSummaryToWhatsApp {
  const SendReportSummaryToWhatsApp(this.exporter);
  final ReportExporter exporter;
  Future<Result<void>> call(
    WeeklyReport report,
    String shopName,
    String phone, {
    bool sellerOnly = false,
  }) => exporter.sendSummaryToWhatsApp(
    report,
    shopName,
    phone,
    sellerOnly: sellerOnly,
  );
}
