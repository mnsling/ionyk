import 'package:flutter/material.dart';
import 'report_printing.dart';
import 'z_reading_history.dart';

class ZReadingPage extends StatefulWidget {
  const ZReadingPage({super.key, this.showHeader = true});
  final bool showHeader;
  @override
  State<ZReadingPage> createState() => _ZReadingPageState();
}

class _ZReadingPageState extends State<ZReadingPage> {
  bool printing = false;
  static const ink = Color(0xFF171B1C);
  static const muted = Color(0xFF687272);
  static const lime = Color(0xFFD9FF57);
  final DateTime date = DateTime.now();
  final ScrollController _reportScrollController = ScrollController();

  @override
  void dispose() {
    _reportScrollController.dispose();
    super.dispose();
  }

  String get dateLabel => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> onPrint() async {
    setState(() => printing = true);
    try {
      await ReportPrinting.printZReading(date: date);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to print: $e')));
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  Widget summary(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: muted))),
      const SizedBox(width: 20),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink)),
    ]),
  );

  Widget _reportContents() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('End-of-day sales summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('Counter 01  •  $dateLabel  •  Sample values', style: const TextStyle(fontSize: 11, color: muted)),
      const SizedBox(height: 17),
      const Divider(),
      summary('Opening invoice no. (sample)', '00001201'),
      summary('Closing invoice no. (sample)', '00001246'),
      summary('Z-Reading number (sample)', '0000018'),
      const Divider(),
      summary('Gross sales', '₱12,500.00'),
      summary('Discounts', '−₱250.00'),
      summary('Refunds / returns', '−₱300.00'),
      const Divider(),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F1), borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Expanded(child: Text('Net sales', style: TextStyle(fontWeight: FontWeight.w600))),
          Text('₱11,950.00', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ]),
      ),
      summary('Transactions', '46'),
      const Divider(),
      summary('VATable sales (illustrative)', '₱10,000.00'),
      summary('VAT amount (illustrative)', '₱1,200.00'),
      summary('VAT-exempt sales (illustrative)', '₱1,300.00'),
      summary('Zero-rated sales (illustrative)', '₱0.00'),
      summary('Voids / cancellations (illustrative)', '₱0.00'),
      summary('Cumulative grand total', 'Unavailable — demo'),
      const Divider(),
      summary('Cash payments', '₱10,150.00'),
      summary('Other payments', '₱1,800.00'),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton.icon(
          onPressed: printing ? null : onPrint,
          icon: const Icon(Icons.print_outlined, size: 17),
          label: Text(printing ? 'Opening print dialog…' : 'Print Z-Reading (Demo)'),
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: lime,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final report = _reportContents();
    if (!widget.showHeader) {
      // In the combined Cash Closing layout, this card fills the same height
      // as Cash Denominations. Only the report itself scrolls.
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E7E3)),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('Z-Reading', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const ZReadingHistoryDialog(),
              ),
              icon: const Icon(Icons.history_outlined, size: 15),
              label: const Text('Past reports', style: TextStyle(fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('End-of-day fiscal report · Demo only', style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6E8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Sample values only. Printing does not close the fiscal day.',
                style: TextStyle(fontSize: 10, color: ink)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              // Gives figures clear breathing room before the vertical scrollbar.
              padding: const EdgeInsets.only(right: 6),
              child: Scrollbar(
                controller: _reportScrollController,
                thumbVisibility: true,
                radius: const Radius.circular(5),
                thickness: 5,
                child: SingleChildScrollView(
                  controller: _reportScrollController,
                  primary: false,
                  padding: const EdgeInsets.only(right: 26, bottom: 16),
                  child: report,
                ),
              ),
            ),
          ),
        ]),
      );
    }
    // Preserve the standalone report view for future use.
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Z-Reading', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w600)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E7E3)),
        ),
        child: report,
      ),
    ]);
  }
}
