import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'report_printing.dart';
import 'z_reading_page.dart';
import 'ionyk_api.dart';

class CashDenominationsPage extends StatefulWidget {
  const CashDenominationsPage({super.key});
  @override
  State<CashDenominationsPage> createState() => _CashDenominationsPageState();
}

class _CashDenominationsPageState extends State<CashDenominationsPage> {
  static const denominations = <double>[1000, 500, 200, 100, 50, 20, 10, 5, 1, .25];
  final controllers = <double, TextEditingController>{for (final d in denominations) d: TextEditingController()};
  bool printing = false;
  bool savingCount = false;
  static const ink = Color(0xFF171B1C);
  static const muted = Color(0xFF687272);
  static const canvas = Color(0xFFF3F4F1);
  static const border = Color(0xFFE2E6E2);

  @override
  void dispose() {
    for (final ctrl in controllers.values) { ctrl.dispose(); }
    super.dispose();
  }

  Map<double, int> get counts => {for (final d in denominations) d: int.tryParse(controllers[d]!.text) ?? 0};
  double get total => counts.entries.fold<double>(0, (sum, item) => sum + item.key * item.value);

  String amount(double n) => '₱${n.toStringAsFixed(2)}';
  String denominationLabel(double d) => d == d.roundToDouble() ? '₱${d.toInt()}' : amount(d);

  Future<void> printCashCount() async {
    setState(() => printing = true);
    try {
      await ReportPrinting.printDenominations(date: DateTime.now(), counts: counts);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to print: $e')));
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  Future<void> saveTestCount() async {
    if (savingCount) return;
    if (counts.values.any((n) => n < 0) ||
        counts.values.every((n) => n == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter your denomination counts before saving a test reconciliation.')));
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Save test cash count?'),
      content: Text('Counted cash: ${amount(total)}\nThis updates today’s DEVELOPMENT count for your counter. It does not close a fiscal day.'),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed: ()=>Navigator.pop(ctx,true),child:const Text('Save test count')),
      ],
    ));
    if (!mounted || ok != true) return;
    setState(()=>savingCount=true);
    try {
      final sent = <String,int>{for (final d in denominations)
        d.toStringAsFixed(2): counts[d]!};
      final result = await const IonykApi().saveTestCashCount(sent);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
        'Saved test count. Expected ${amount((num.tryParse('${result['expected_cash']}')??0).toDouble())}; '
        'variance ${amount((num.tryParse('${result['variance']}')??0).toDouble())}.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('Unable to save test count: $e')));
    } finally {if (mounted) setState(()=>savingCount=false);}
  }

  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: border), borderRadius: BorderRadius.circular(16)), child: child,
  );

  // Keep totals and printing visible. Only the countable denominations scroll.
  Widget denominationPanel() => panel(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Cash denomination count',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      const SizedBox(height: 5),
      const Text('Enter number of bills and coins.',
          style: TextStyle(fontSize: 11, color: muted)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: canvas, borderRadius: BorderRadius.circular(9)),
        child: const Row(children: [
          Expanded(child: Text('DENOMINATION',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
          SizedBox(width: 90, child: Text('PIECES',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
        ]),
      ),
      const SizedBox(height: 2),
      Expanded(
        child: Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.only(right: 8),
            itemCount: denominations.length,
            itemBuilder: (context, index) {
              final d = denominations[index];
              return Container(
                height: 39,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: border))),
                child: Row(children: [
                  Expanded(child: Text(denominationLabel(d),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  SizedBox(
                    width: 90,
                    height: 30,
                    child: TextField(
                      controller: controllers[d],
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '—',
                        hintStyle: const TextStyle(color: Color(0xFF9DA79F)),
                        filled: true,
                        fillColor: canvas,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: canvas, borderRadius: BorderRadius.circular(11)),
        child: Row(children: [
          const Expanded(child: Text('Total counted cash',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          Text(amount(total),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity, height: 43,
        child: OutlinedButton.icon(
          onPressed: savingCount ? null : saveTestCount,
          icon: const Icon(Icons.save_outlined, size: 17),
          label: Text(savingCount ? 'Saving test count…' : 'Save test cash count'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        height: 43,
        child: FilledButton.icon(
          onPressed: printing ? null : printCashCount,
          icon: const Icon(Icons.print_outlined, size: 17),
          label: Text(printing ? 'Opening print dialog…' : 'Print Cash Denominations'),
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: const Color(0xFFD9FF57),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ],
  ));

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    LayoutBuilder(
      builder: (context, constraints) {
        const panelHeight = 680.0;
        final sideBySide = constraints.maxWidth >= 920;
        final cashCard = SizedBox(
          height: panelHeight,
          child: denominationPanel(),
        );
        final zCard = const SizedBox(
          height: panelHeight,
          child: ZReadingPage(showHeader: false),
        );
        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cashCard),
              const SizedBox(width: 16),
              Expanded(child: zCard),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cashCard,
            const SizedBox(height: 16),
            zCard,
          ],
        );
      },
    ),
    const SizedBox(height: 12),
    const Text(
      'Development cash counts can be saved for testing. Printing does not close a fiscal day or produce a BIR Z-reading.',
      style: TextStyle(color: muted, fontSize: 10),
    ),
  ]);
}
