import 'package:flutter/material.dart';
import 'ionyk_api.dart';
import 'ionyk_date_filter.dart';
import 'dev_cash_report.dart';

/// Development-test transactions from PostgreSQL, not official fiscal invoices.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  static const ink = Color(0xFF171D1B);
  static const muted = Color(0xFF687272);
  static const lime = Color(0xFFD9FF57);
  static const border = Color(0xFFE2E6E2);
  final api = const IonykApi();
  late Future<List<Map<String, dynamic>>> history;
  DateTimeRange? range;
  Map<String, dynamic>? selectedReceipt;
  int? selectedId;
  bool receiptLoading = false;
  bool printingReceipt = false;
  late Future<Map<String,dynamic>> businessHeader;
  Future<void> printSelectedReceipt() async {
    final receipt=selectedReceipt;
    if(receipt==null || printingReceipt) return;
    setState(()=>printingReceipt=true);
    try {
      final settings=await api.receiptSettings();
      await DevCashReport.printSale(receipt:receipt,settings:settings);
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('Unable to print development receipt: $e')));
    } finally {if(mounted)setState(()=>printingReceipt=false);}
  }


  @override
  void initState() {
    super.initState();
    history = api.testTransactions();
    businessHeader=api.receiptSettings();
  }

  void refresh() {
    final nextHistory = api.testTransactions();
    setState(() {
      history = nextHistory;
    });
  }
  String money(Object? raw) => '₱${(num.tryParse('$raw') ?? 0).toStringAsFixed(2)}';
  DateTime? parseDate(Object? raw) => DateTime.tryParse('$raw')?.toLocal();
  String stamp(Object? value) {
    final dt = parseDate(value);
    if (dt == null) return '--';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(dt.month)}/${p(dt.day)}/${dt.year}  ${p(dt.hour)}:${p(dt.minute)}';
  }

  bool inRange(Map<String, dynamic> sale) {
    if (range == null) return true;
    final day = parseDate(sale['created_at']);
    if (day == null) return false;
    final date = DateUtils.dateOnly(day);
    return !date.isBefore(DateUtils.dateOnly(range!.start)) &&
        !date.isAfter(DateUtils.dateOnly(range!.end));
  }

  Future<void> chooseRange() async {
    final result = await IonykDateFilter.range(context, selected: range);
    if (!mounted || result == null) return;
    setState(() => range = result.clear ? null : result.range);
  }

  Future<void> selectReceipt(int id) async {
    setState(() { selectedId = id; receiptLoading = true; selectedReceipt = null; });
    try {
      final value = await api.testReceipt(id);
      if (!mounted || selectedId != id) return;
      setState(() => selectedReceipt = value);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load receipt: $error')));
    } finally {
      if (mounted && selectedId == id) setState(() => receiptLoading = false);
    }
  }

  Widget amountRow(String label, Object? amount, {bool strong = false}) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(
            fontWeight: strong ? FontWeight.w700 : FontWeight.w400, fontSize: 12))),
        Text(money(amount), style: TextStyle(
            fontWeight: strong ? FontWeight.w700 : FontWeight.w500, fontSize: strong ? 17 : 12)),
      ]));

  Widget receiptPanel() {
    if (receiptLoading) return const Center(child: CircularProgressIndicator());
    final receipt = selectedReceipt;
    if (receipt == null) return const Center(child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_outlined, size: 36, color: muted),
        SizedBox(height: 12),
        Text('Select a receipt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        SizedBox(height: 6),
        Text('Receipt details will appear here', style: TextStyle(color: muted, fontSize: 12)),
      ]));
    final lines = (receipt['lines'] as List?) ?? const [];
    return SingleChildScrollView(padding: const EdgeInsets.all(22), child: Center(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 410), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FutureBuilder<Map<String,dynamic>>(future:businessHeader,
            builder:(ctx,snap)=>Center(child:Text(
              '${snap.data?['business']??'IONYK SYSTEMS'}',
              style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)))),
          const SizedBox(height: 5),
          const Center(child: Text('DEVELOPMENT TEST RECEIPT', style: TextStyle(
              color: muted, fontSize: 10, letterSpacing: .6))),
          const SizedBox(height: 20),
          Text('Receipt #${receipt['receipt_no'] ?? receipt['id'] ?? selectedId}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text('Date: ${stamp(receipt['created_at'])}', style: const TextStyle(fontSize: 12)),
          Text('Counter: ${receipt['terminal_id'] ?? '--'}', style: const TextStyle(fontSize: 12)),
          Text('Cashier: ${receipt['cashier'] ?? '--'}', style: const TextStyle(fontSize: 12)),
          const Divider(height: 28),
          for (final raw in lines) Builder(builder: (_) {
            final line = Map<String, dynamic>.from(raw as Map);
            return Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${line['description'] ?? 'Product'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text('${line['quantity']} × ${money(line['unit_price'])} · ${line['unit'] ?? 'piece'}',
                      style: const TextStyle(color: muted, fontSize: 11)),
                ])),
                const SizedBox(width: 9),
                Text(money(line['line_total']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ]));
          }),
          const Divider(height: 25),
          amountRow('Total', receipt['total'], strong: true),
          amountRow('Cash received', receipt['tendered']),
          amountRow('Change', receipt['change_due']),
          const SizedBox(height: 25),
          const Center(child: Text('NOT AN OFFICIAL BIR INVOICE', style: TextStyle(
              fontSize: 10, color: muted, fontWeight: FontWeight.w600))),
          const Center(child: Text('Development test transaction only',
              style: TextStyle(fontSize: 10, color: muted))),
        ]))));
  }

  Widget frame(Widget child) => Container(
    decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: border), borderRadius: BorderRadius.circular(17)),
    child: child);

  Widget card(Map<String, dynamic> sale) {
    final id = (sale['id'] as num).toInt();
    final active = id == selectedId;
    return InkWell(onTap: () => selectReceipt(id), borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF0F7D8) : const Color(0xFFF9FAF7),
          border: Border.all(color: active ? const Color(0xFF9AC52B) : border),
          borderRadius: BorderRadius.circular(13)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.receipt_outlined, size: 18, color: ink),
            const Spacer(), Text('TEST', style: TextStyle(
              color: active ? ink : muted, fontSize: 10, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 10),
          Text('Receipt #${sale['receipt_no'] ?? id}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 3),
          Text(stamp(sale['created_at']), style: const TextStyle(fontSize: 11, color: muted)),
          const Spacer(),
          Text(money(sale['total']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Counter ${sale['terminal_id']} · ${sale['item_count'] ?? 0} items',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: muted)),
        ])));
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [
      const Expanded(child: Text('Transactions', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700))),
      TextButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 17), label: const Text('Refresh')),
    ]),
    const SizedBox(height: 5),
    const Text('Saved development test receipts · not official BIR invoices',
      style: TextStyle(fontSize: 12, color: muted)),
    const SizedBox(height: 17),
    SizedBox(
      // DashboardShell places this page inside a SingleChildScrollView.
      // Expanded cannot receive an unbounded vertical constraint there.
      height: (MediaQuery.sizeOf(context).height - 210).clamp(520.0, 1200.0),
      child: LayoutBuilder(builder: (context, limits) {
      final wide = limits.maxWidth > 920;
      final left = frame(Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, 15, 18, 12), child: Row(children: [
          const Icon(Icons.grid_view_rounded, size: 18), const SizedBox(width: 8),
          const Expanded(child: Text('Sales history', style: TextStyle(fontWeight: FontWeight.w700))),
          OutlinedButton.icon(onPressed: chooseRange,
            icon: const Icon(Icons.calendar_today_outlined, size: 15),
            label: Text(range == null ? 'All dates' :
              '${IonykDateFilter.label(range!.start)} – ${IonykDateFilter.label(range!.end)}',
              style: const TextStyle(fontSize: 11))),
          if (range != null) IconButton(tooltip: 'Clear date filter',
              onPressed: () => setState(() => range = null), icon: const Icon(Icons.close, size: 17)),
        ])),
        const Divider(height: 1),
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: history, builder: (ctx, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16),
            child: Text('Could not load transactions: ${snapshot.error}', textAlign: TextAlign.center)));
          final sales = (snapshot.data ?? []).where(inRange).toList();
          if (sales.isEmpty) return const Center(child: Text('No receipts for this date range',
            style: TextStyle(color: muted)));
          return LayoutBuilder(builder: (ctx, area) {
            final columns = area.maxWidth >= 420 ? 2 : 1;
            return GridView.builder(padding: const EdgeInsets.all(15), itemCount: sales.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns,
                mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 166),
              itemBuilder: (ctx, index) => card(sales[index]));
          });
        })),
      ]));
      final right = frame(Column(children: [
        Padding(padding:const EdgeInsets.all(15),child:Row(children:[
          const Icon(Icons.receipt_long_outlined,size:18),
          const SizedBox(width:9),
          const Expanded(child:Text('Receipt preview',
            style:TextStyle(fontWeight:FontWeight.w700))),
          TextButton.icon(onPressed:selectedReceipt==null||printingReceipt?null:printSelectedReceipt,
            icon:const Icon(Icons.print_outlined,size:16),
            label:const Text('Print TEST')),
        ])),
        const Divider(height: 1),
        Expanded(child: receiptPanel()),
      ]));
      if (wide) return Row(children: [Expanded(flex: 6, child: left),
        const SizedBox(width: 13), Expanded(flex: 4, child: right)]);
      return Column(children: [Expanded(child: left), const SizedBox(height: 12), Expanded(child: right)]);
    })),
  ]);
}
