import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'ionyk_api.dart';
import 'ionyk_date_filter.dart';

/// A printable DEVELOPMENT SALES SUMMARY, not an official fiscal Z-reading.
/// Uses saved test transactions for the signed-in cashier only.
class ZReadingPage extends StatefulWidget {
  const ZReadingPage({super.key, this.showHeader = true});
  final bool showHeader;
  @override
  State<ZReadingPage> createState() => _ZReadingPageState();
}

class _ZReadingPageState extends State<ZReadingPage> {
  static const muted = Color(0xFF687272);
  static const border = Color(0xFFE2E6E2);
  late Future<List<Map<String, dynamic>>> history;
  DateTimeRange? selectedRange;
  bool printing = false;

  @override
  void initState() {
    super.initState();
    history = const IonykApi().testTransactions();
  }

  void reload() {
    final nextHistory = const IonykApi().testTransactions();
    if (!mounted) return;
    setState(() {
      history = nextHistory;
    });
  }
  String money(Object? n) => '₱${(num.tryParse('$n') ?? 0).toStringAsFixed(2)}';
  String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  DateTimeRange get range => selectedRange ?? DateTimeRange(
      start: DateUtils.dateOnly(DateTime.now()), end: DateUtils.dateOnly(DateTime.now()));
  bool includes(Map<String, dynamic> sale) {
    final date = DateTime.tryParse('${sale['created_at']}')?.toLocal();
    if (date == null) return false;
    final current = DateUtils.dateOnly(date);
    return !current.isBefore(DateUtils.dateOnly(range.start)) &&
        !current.isAfter(DateUtils.dateOnly(range.end));
  }

  Future<void> selectRange() async {
    final result = await IonykDateFilter.range(context, selected: range);
    if (!mounted || result == null) return;
    setState(() => selectedRange = result.clear ? null : result.range);
  }

  Future<void> showPastDays(List<Map<String, dynamic>> sales) async {
    final dates = <DateTime>{};
    for (final sale in sales) {
      final timestamp = DateTime.tryParse('${sale['created_at']}')?.toLocal();
      if (timestamp != null) dates.add(DateUtils.dateOnly(timestamp));
    }
    final ordered = dates.toList()..sort((a, b) => b.compareTo(a));
    if (ordered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No saved test sales dates available yet')));
      return;
    }
    final chosen = await showDialog<DateTime>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Past test-sales dates'),
      content: SizedBox(width: 340, height: 320, child: ListView.builder(
        itemCount: ordered.length,
        itemBuilder: (ctx, index) {
          final value = ordered[index];
          final count = sales.where((r) {
            final d = DateTime.tryParse('${r['created_at']}')?.toLocal();
            return d != null && DateUtils.isSameDay(d, value);
          }).length;
          return ListTile(
            leading: const Icon(Icons.calendar_today_outlined, size: 19),
            title: Text(day(value)), subtitle: Text('$count saved test receipts'),
            onTap: () => Navigator.pop(ctx, value));
        })),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
    if (chosen != null && mounted) setState(() => selectedRange =
      DateTimeRange(start: chosen, end: chosen));
  }

  Future<void> printSummary(List<Map<String, dynamic>> records) async {
    if (records.isEmpty || printing) return;
    setState(() => printing = true);
    try {
      final total = records.fold<double>(0, (n, s) => n + (num.tryParse('${s['total']}') ?? 0).toDouble());
      final count = records.fold<int>(0, (n, s) => n + (num.tryParse('${s['item_count']}') ?? 0).toInt());
      final doc = pw.Document();
      pw.Widget line(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Text(label), pw.Text(value)]));
      doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          pw.Center(child: pw.Text('IONYK SYSTEMS',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18))),
          pw.SizedBox(height: 10),
          pw.Center(child: pw.Text('DEVELOPMENT TEST SALES SUMMARY',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13))),
          pw.Center(child: pw.Text('NOT A Z-READING / NOT AN OFFICIAL BIR REPORT',
            style: const pw.TextStyle(fontSize: 9))),
          pw.Divider(),
          line('Date range', '${day(range.start)} to ${day(range.end)}'),
          line('Cashier', IonykApi.currentDisplayName ?? '--'),
          line('Counter ID', '${IonykApi.currentTerminalId ?? '--'}'),
          line('Saved test transactions', '${records.length}'),
          line('Items sold', '$count'),
          line('Test sales total', 'PHP ${total.toStringAsFixed(2)}'),
          pw.Divider(),
          pw.Text('Transaction records (development only)',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (final sale in records) line('Test receipt #${sale['id']}',
            'PHP ${(num.tryParse('${sale['total']}') ?? 0).toStringAsFixed(2)}'),
          pw.SizedBox(height: 15),
          pw.Text('This printout does not close a fiscal day, issue a Z number, record tax declarations or replace a BIR-compliant Z-reading.',
            style: const pw.TextStyle(fontSize: 9)),
        ]));
      await Printing.layoutPdf(onLayout: (_) async => doc.save(),
        name: 'IONYK_Development_Sales_Summary');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printing failed: $error')));
    } finally { if (mounted) setState(() => printing = false); }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: border), borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.showHeader) const Padding(padding: EdgeInsets.only(bottom: 10),
        child: Text('Test closing summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
      Row(children: [const Expanded(child: Text('Test closing summary',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        IconButton(onPressed: reload, tooltip: 'Refresh sales', icon: const Icon(Icons.refresh, size: 18)),
      ]),
      const SizedBox(height: 4),
      const Text('Saved test receipts only. Not a fiscal Z-reading.',
        style: TextStyle(fontSize: 11, color: muted)),
      const SizedBox(height: 13),
      OutlinedButton.icon(onPressed: selectRange, icon: const Icon(Icons.calendar_month_outlined, size: 17),
        label: Text('${IonykDateFilter.label(range.start)} – ${IonykDateFilter.label(range.end)}',
          style: const TextStyle(fontSize: 11))),
      const SizedBox(height: 12),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: history, builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Could not load sales: ${snap.error}', textAlign: TextAlign.center));
        final records = (snap.data ?? []).where(includes).toList();
        final total = records.fold<double>(0, (sum, s) => sum + (num.tryParse('${s['total']}') ?? 0).toDouble());
        final pieces = records.fold<int>(0, (sum, s) => sum + (num.tryParse('${s['item_count']}') ?? 0).toInt());
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(
            color: const Color(0xFFF3F5F1), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _row('Test transactions', '${records.length}'),
              const SizedBox(height: 9), _row('Items sold', '$pieces'),
              const Divider(height: 23), _row('Test sales total', money(total), strong: true),
            ])),
          const SizedBox(height: 15),
          const Text('Receipts in date range', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          Expanded(child: records.isEmpty ? const Center(child: Text('No saved test sales for this period',
            style: TextStyle(color: muted, fontSize: 12))) :
            ListView.builder(itemCount: records.length, itemBuilder: (ctx, i) {
              final r = records[i];
              return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
                Expanded(child: Text('Test receipt #${r['id']}', style: const TextStyle(fontSize: 12))),
                Text(money(r['total']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ]));
            })),
          const SizedBox(height: 9),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => showPastDays(snap.data ?? []),
            icon: const Icon(Icons.history, size: 17),
            label: const Text('Past test reports · choose date'))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: records.isEmpty || printing ? null : () => printSummary(records),
            icon: const Icon(Icons.print_outlined, size: 17),
            label: Text(printing ? 'Opening print dialog…' : 'Print test sales summary'))),
        ]);
      })),
      const SizedBox(height: 10),
      const Text('Official Z-readings require a separate audited, BIR-compliant end-of-day closing process.',
        style: TextStyle(fontSize: 10, color: muted)),
    ]));

  Widget _row(String label, String value, {bool strong = false}) => Row(children: [
    Expanded(child: Text(label, style: TextStyle(fontSize: 12,
      fontWeight: strong ? FontWeight.w700 : FontWeight.w400))),
    Text(value, style: TextStyle(fontSize: strong ? 17 : 12, fontWeight: FontWeight.w700)),
  ]);
}
