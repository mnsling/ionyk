import 'package:flutter/material.dart';
import 'ionyk_modal.dart';
import 'ionyk_date_filter.dart';

/// Sample invoice/transaction browser. All records are fictional and in-memory.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _DemoSale {
  const _DemoSale(this.id, this.invoice, this.date, this.counter, this.type, this.status, this.products, this.discount);
  final String id, invoice, counter, type, status;
  final DateTime date;
  final List<(String, int, double)> products;
  final double discount;
  double get subtotal => products.fold(0.0, (s, p) => s + p.$2 * p.$3);
  double get total => subtotal - discount;
}

class _TransactionsPageState extends State<TransactionsPage> {
  static const ink = Color(0xFF151A1A), muted = Color(0xFF657169), line = Color(0xFFE3E8DF), lime = Color(0xFFD9FF57);
  final sales = <_DemoSale>[
    _DemoSale('TX-00428', '00000428', DateTime(2026, 11, 10, 14, 35), '01', 'Retail', 'Completed', [('Piattos Cheese 85g', 2, 30), ('Coca-Cola 1.5L', 1, 78)], 0),
    _DemoSale('TX-00427', '00000427', DateTime(2026, 11, 10, 13, 10), '01', 'Wholesale', 'Completed', [('Lucky Me Pancit Canton', 12, 18), ('Nescafé Classic 50g', 3, 72)], 0),
    _DemoSale('TX-00426', '00000426', DateTime(2026, 11, 9, 17, 42), '02', 'Retail', 'Refund requested', [('Coca-Cola 1.5L', 2, 78)], 0),
    _DemoSale('TX-00425', '00000425', DateTime(2026, 11, 8, 9, 25), '03', 'Retail', 'Completed', [('Piattos Cheese 85g', 4, 30), ('Nova BBQ 78g', 2, 26)], 10),
  ];
  DateTime? selectedDate;
  bool gridView = false;
  int chosen = 0;
  String _cash(double n) => '₱${n.toStringAsFixed(2)}';
  String _date(DateTime v) => '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  List<_DemoSale> get visible {
    if (selectedDate == null) return sales;
    return sales.where((sale) =>
      sale.date.year == selectedDate!.year &&
      sale.date.month == selectedDate!.month &&
      sale.date.day == selectedDate!.day,
    ).toList();
  }

  Future<void> _pickDate() async {
    final choice = await IonykDateFilter.single(
      context,
      selected: selectedDate,
      initial: DateTime(2026, 11, 10),
    );
    if (!mounted || choice == null) return;
    setState(() {
      selectedDate = choice.clear ? null : choice.date;
      chosen = 0;
    });
  }
  Widget _card(Widget child, {EdgeInsets padding = const EdgeInsets.all(20)}) => Container(padding: padding,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: line)), child: child);
  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$value — demonstration only; no records were changed.')));
  Future<void> _refundRequest(_DemoSale sale) async {
    final reason = TextEditingController();
    final send = await showDialog<bool>(context: context, builder: (ctx) => IonykModal(
      title: const Text('Request refund approval'),
      content: SizedBox(width: 350, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Transaction ${sale.id} · ${_cash(sale.total)}'),
        const SizedBox(height: 12),
        TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Reason', hintText: 'Explain the return or issue')),
        const SizedBox(height: 12),
        const Text('Production: require supervisor approval, item quantities, original tender, stock disposition, and audit trail.', style: TextStyle(fontSize: 11, color: muted)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (reason.text.trim().isNotEmpty) Navigator.pop(ctx, true); }, child: const Text('Preview request'))],
    ));
    reason.dispose();
    if (!mounted) return;
    if (send == true) _message('Refund request for ${sale.id}');
  }
  @override
  Widget build(BuildContext context) {
    final current = visible;
    final selected = current.isEmpty ? null : current[chosen.clamp(0, current.length - 1).toInt()];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, c) => c.maxWidth >= 880
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 7, child: _saleList(current)), const SizedBox(width: 16),
            Expanded(flex: 4, child: _invoicePreview(selected)),
          ])
        : Column(children: [_saleList(current), const SizedBox(height: 15), _invoicePreview(selected)])),
    ]);
  }
  Widget _saleList(List<_DemoSale> records) => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sales history', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        SizedBox(height: 5),
        Text('Select a transaction to view its original invoice', style: TextStyle(color: muted, fontSize: 11)),
      ])),
      const SizedBox(width: 10),
      OutlinedButton.icon(
        onPressed: _pickDate,
        icon: const Icon(Icons.calendar_month_outlined, size: 15),
        label: Text(selectedDate == null ? 'All dates' : _date(selectedDate!),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          minimumSize: const Size(0, 37),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      if (selectedDate != null) IconButton(
        tooltip: 'Clear date filter',
        onPressed: () => setState(() { selectedDate = null; chosen = 0; }),
        icon: const Icon(Icons.close_rounded, size: 17),
        color: muted,
      ),
      const SizedBox(width: 10),
      Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: const Color(0xFFF3F5F1), borderRadius: BorderRadius.circular(9)),
        child: Row(children: [
          _viewToggle(Icons.view_list_rounded, 'List', !gridView, () => setState(() => gridView = false)),
          _viewToggle(Icons.grid_view_rounded, 'Grid', gridView, () => setState(() => gridView = true)),
        ])),
    ]),
    const SizedBox(height: 15),
    if (records.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Text('No transactions for this date.', style: TextStyle(color: muted)))
    else if (gridView) LayoutBuilder(builder: (context, constraints) => GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: records.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: constraints.maxWidth > 540 ? 2 : 1, crossAxisSpacing: 10, mainAxisSpacing: 10, mainAxisExtent: 132),
      itemBuilder: (context, i) => _saleTile(records[i], chosen == i, i, true),
    ))
    else for (var i = 0; i < records.length; i++) Padding(
      padding: const EdgeInsets.only(bottom: 9), child: _saleTile(records[i], chosen == i, i, false)),
  ]));

  Widget _viewToggle(IconData icon, String label, bool active, VoidCallback onTap) => Tooltip(
    message: '$label view', child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Container(
      padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: active ? ink : Colors.transparent, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: active ? Colors.white : muted),
    )));

  Widget _saleTile(_DemoSale s, bool active, int i, bool grid) => InkWell(
    onTap: () => setState(() => chosen = i), borderRadius: BorderRadius.circular(11), child: Container(
      padding: const EdgeInsets.all(13), decoration: BoxDecoration(
        color: active ? const Color(0xFFF1F8D9) : const Color(0xFFF8F9F7),
        borderRadius: BorderRadius.circular(11), border: Border.all(color: active ? const Color(0xFFA7C547) : line)),
      child: grid ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Expanded(child: Text(s.id, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          _status(s.status)]),
        Text('${_date(s.date)}  ·  ${s.date.hour.toString().padLeft(2,'0')}:${s.date.minute.toString().padLeft(2,'0')}',
          style: const TextStyle(fontSize: 10, color: muted)),
        Row(children: [Text(s.type, style: const TextStyle(fontSize: 10, color: muted)), const Spacer(),
          Text(_cash(s.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))]),
      ]) : Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.id, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 5),
          Text('${_date(s.date)} · ${s.date.hour.toString().padLeft(2,'0')}:${s.date.minute.toString().padLeft(2,'0')} · ${s.type}',
            style: const TextStyle(fontSize: 10, color: muted)),
        ])),
        _status(s.status), const SizedBox(width: 14),
        Text(_cash(s.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    ));

  Widget _status(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: text == 'Completed' ? const Color(0xFFE3EFD1) : const Color(0xFFFFEAD6), borderRadius: BorderRadius.circular(7)),
    child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)));

  Widget _invoicePreview(_DemoSale? s) => _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [const Expanded(child: Text('Invoice preview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
      if (s != null) FilledButton.icon(onPressed: () => _message('Invoice reprint for ${s.invoice}'), icon: const Icon(Icons.print_outlined, size: 16), label: const Text('Reprint invoice'), style: FilledButton.styleFrom(backgroundColor: ink, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))]),
    const SizedBox(height: 12),
    if (s == null) const Padding(padding: EdgeInsets.all(40), child: Text('Select a transaction.', textAlign: TextAlign.center))
    else ...[
      Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26), color: const Color(0xFFFAFAF7), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('SAMPLE STORE', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 5),
        const Text('PREVIEW ONLY · NOT A VALID TAX INVOICE', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 9)),
        const SizedBox(height: 16),
        Text('INVOICE NO: ${s.invoice}\nDATE: ${_date(s.date)}\nCASHIER 1 · COUNTER 01\nTYPE: ${s.type}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.6)),
        const SizedBox(height: 12),
        const Text('----------------------------------------', overflow: TextOverflow.clip, maxLines: 1, style: TextStyle(fontFamily: 'monospace')),
        const SizedBox(height: 6),
        for (final p in s.products) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
          Expanded(child: Text('${p.$1}\n${p.$2} × ${_cash(p.$3)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5))),
          Text(_cash(p.$2 * p.$3), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        ])),
        const Text('----------------------------------------', overflow: TextOverflow.clip, maxLines: 1, style: TextStyle(fontFamily: 'monospace')),
        _sumRow('SUBTOTAL', _cash(s.subtotal)),
        _sumRow('DISCOUNT', '-${_cash(s.discount)}'),
        const SizedBox(height: 8),
        _sumRow('AMOUNT', _cash(s.total), bold: true),
        const SizedBox(height: 20),
        const Text('THANK YOU FOR SHOPPING', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
        const SizedBox(height: 12),
        const Text('Tax IDs, approved numbering and mandatory invoice fields will be added after compliance review.', style: TextStyle(fontSize: 9.5, color: muted), textAlign: TextAlign.center),
      ])),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => _message('Invoice viewing'), child: const Text('View invoice', style: TextStyle(fontSize: 11)))),
        const SizedBox(width: 10),
        Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: ink), onPressed: () => _refundRequest(s), child: const Text('Request refund', style: TextStyle(fontSize: 11)))),
      ]),
    ],
    const SizedBox(height: 13),
    const Text('Fictional sample records. No invoice is generated, printed, or stored by this page.', style: TextStyle(fontSize: 10, color: muted)),
  ]));
  Widget _sumRow(String label, String amount, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
    Expanded(child: Text(label, style: TextStyle(fontFamily: 'monospace', fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 13 : 11))),
    Text(amount, style: TextStyle(fontFamily: 'monospace', fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 13 : 11)),
  ]));
}
