import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'z_reading_record.dart';

/// DEMO documents only. These are NOT registered BIR Z-Readings or tax invoices.
class ReportPrinting {
  static String money(num n) => 'PHP ${n.toStringAsFixed(2)}';

  static pw.Widget _line(String label, String value, {bool strong = false}) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ));

  static pw.Document _document(String heading, List<pw.Widget> content) {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(38),
      build: (context) => [
        pw.Center(child: pw.Text('IONYK SYSTEMS', style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 7),
        pw.Center(child: pw.Text(heading, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 7),
        pw.Center(child: pw.Text('DEMO PREVIEW - NOT AN OFFICIAL BIR REPORT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
        pw.Divider(),
        ...content,
        pw.Divider(),
        pw.Center(child: pw.Text('Sample report - no live transactions, no fiscal closing.', style: const pw.TextStyle(fontSize: 9))),
      ],
    ));
    return doc;
  }

  static Future<void> printZReading({required DateTime date}) async {
    final stamp = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final doc = _document('END-OF-DAY Z-READING PREVIEW', [
      _line('Date', stamp),
      _line('Terminal', 'COUNTER 01'),
      _line('Cashier', 'Cashier 1 (example)'),
      _line('Status', 'NOT CLOSED - PREVIEW ONLY'),
      pw.Divider(),
      _line('Z number (sample)', '0000018'),
      _line('Beginning invoice (sample)', '00001201'),
      _line('Ending invoice (sample)', '00001246'),
      pw.Divider(),
      _line('Gross sales (sample)', money(12500)),
      _line('Discounts (sample)', money(250)),
      _line('Refunds / returns (sample)', money(300)),
      _line('Net sales (sample)', money(11950), strong: true),
      pw.Divider(),
      _line('VATable sales (illustrative)', money(10000)),
      _line('VAT amount (illustrative)', money(1200)),
      _line('VAT exempt sales (illustrative)', money(1300)),
      _line('Zero-rated sales (illustrative)', money(0)),
      _line('Voids (illustrative)', money(0)),
      _line('Non-resettable accumulated total', 'N/A - demo'),
      pw.Divider(),
      _line('Cash payments (sample)', money(10150)),
      _line('Other payments (sample)', money(1800)),
      _line('Number of transactions (sample)', '46'),
      pw.SizedBox(height: 13),
      pw.Text('Additional BIR-required fields, tax details, grand totals, and counter sequences will be supplied by the approved live system.', style: const pw.TextStyle(fontSize: 9)),
    ]);
    await _print(doc, 'IONYK_Z_Reading_DEMO');
  }

  /// Prints labeled COPIES of selected stored Z-Reading snapshots. No new fiscal
  /// Z numbers are generated. Real source must be immutable server history.
  static Future<void> reprintZReadings(List<ZReadingRecord> records) async {
    if (records.isEmpty) return;
    final doc = pw.Document();
    for (final r in records) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        build: (_) => [
          pw.Center(child: pw.Text('IONYK SYSTEMS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 10),
          pw.Center(child: pw.Text('Z-READING REPRINT — COPY', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text('DEMO SNAPSHOT — NOT AN OFFICIAL BIR REPORT', style: const pw.TextStyle(fontSize: 9))),
          pw.Divider(),
          _line('Closing date', zDate(r.date)),
          _line('Counter', r.counter),
          _line('Original Z number', r.id),
          _line('Opening invoice', r.openingInvoice),
          _line('Closing invoice', r.closingInvoice),
          _line('Transactions', '${r.transactions}'),
          pw.Divider(),
          _line('Gross sales', money(r.gross)),
          _line('Discounts', money(r.discounts)),
          _line('Refunds', money(r.refunds)),
          _line('Net sales', money(r.net), strong: true),
          pw.Divider(),
          _line('Cash payments', money(r.cash)),
          _line('Other payments', money(r.otherPayments)),
          pw.SizedBox(height: 18),
          pw.Text('COPY — printing does not close the fiscal day or modify any transaction.', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('BIR-specific tax breakdowns, signatures, MIN/PTU details, and counter totals are unavailable in the UI prototype.', style: const pw.TextStyle(fontSize: 9)),
        ],
      ));
    }
    await _print(doc, 'IONYK_Z_Reprints_DEMO');
  }

  /// Operational multi-day aggregation; this is NOT itself a Z-Reading.
  static Future<void> printZReadingSummary(List<ZReadingRecord> records) async {
    if (records.isEmpty) return;
    double sum(double Function(ZReadingRecord) field) =>
        records.fold<double>(0, (a, r) => a + field(r));
    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
    final lines = <pw.Widget>[
      _line('Counter', sorted.first.counter),
      _line('Selected closing days', '${records.length}'),
      _line('From', zDate(sorted.first.date)),
      _line('Through', zDate(sorted.last.date)),
      pw.Divider(),
      ...sorted.map((r) => _line('${zDate(r.date)}  Z #${r.id}', money(r.net))),
      pw.Divider(),
      _line('Gross sales', money(sum((r) => r.gross))),
      _line('Discounts', money(sum((r) => r.discounts))),
      _line('Refunds', money(sum((r) => r.refunds))),
      _line('NET SALES', money(sum((r) => r.net)), strong: true),
      _line('Cash payments', money(sum((r) => r.cash))),
      _line('Other payments', money(sum((r) => r.otherPayments))),
      _line('Transactions', '${records.fold<int>(0, (a, r) => a + r.transactions)}'),
      pw.SizedBox(height: 16),
      pw.Text('Selected-day summary only. Not an original fiscal Z-Reading or registered BIR report.', style: const pw.TextStyle(fontSize: 9)),
    ];
    await _print(_document('SELECTED Z-READING SUMMARY (DEMO)', lines), 'IONYK_Z_Summary_DEMO');
  }

  static Future<void> printDenominations({
    required DateTime date,
    required Map<double, int> counts,
  }) async {
    final total = counts.entries.fold<double>(0, (sum, e) => sum + e.key * e.value);
    final stamp = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final lines = <pw.Widget>[
      _line('Date', stamp),
      _line('Terminal', 'COUNTER 01'),
      _line('Cashier', 'Cashier 1 (example)'),
      pw.Divider(),
      ...counts.entries.map((e) => _line('${money(e.key)} x ${e.value}', money(e.key * e.value))),
      pw.Divider(),
      _line('TOTAL COUNTED CASH', money(total), strong: true),
      pw.SizedBox(height: 18),
      pw.Text('Cashier signature: __________________________', style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 12),
      pw.Text('Verified by: _________________________________', style: const pw.TextStyle(fontSize: 10)),
    ];
    await _print(_document('CASH DENOMINATION COUNT', lines), 'IONYK_Cash_Count_DEMO');
  }

  static Future<void> _print(pw.Document doc, String name) async {
    try {
      await Printing.layoutPdf(name: name, onLayout: (format) async => doc.save());
    } catch (error) {
      debugPrint('Printing failed: $error');
      rethrow;
    }
  }
}
