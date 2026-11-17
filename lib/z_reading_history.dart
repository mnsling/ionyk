import 'package:flutter/material.dart';
import 'report_printing.dart';

import 'z_reading_record.dart';
import 'ionyk_date_filter.dart';

/// History viewer designed for the same IONYK dashboard theme.
/// Multiple selections print as clearly labeled COPY pages, not fresh fiscal closes.
class ZReadingHistoryDialog extends StatefulWidget {
  const ZReadingHistoryDialog({super.key});

  @override
  State<ZReadingHistoryDialog> createState() => _ZReadingHistoryDialogState();
}

class _ZReadingHistoryDialogState extends State<ZReadingHistoryDialog> {
  static const ink = Color(0xFF171B1C);
  static const muted = Color(0xFF687272);
  static const lime = Color(0xFFD9FF57);
  static const line = Color(0xFFE4E8E4);
  final Set<String> selectedIds = {};
  DateTimeRange? range;
  String? previewId;
  bool busy = false;

  List<ZReadingRecord> get visible => demoZReadings.where((r) {
    if (range == null) return true;
    final day = DateUtils.dateOnly(r.date);
    return !day.isBefore(DateUtils.dateOnly(range!.start)) && !day.isAfter(DateUtils.dateOnly(range!.end));
  }).toList();

  ZReadingRecord get currentPreview => demoZReadings.firstWhere(
    (r) => r.id == previewId,
    orElse: () => visible.isNotEmpty ? visible.first : demoZReadings.first,
  );

  Future<void> pickDate() async {
    final choice = await IonykDateFilter.range(context, selected: range);
    if (!mounted || choice == null) return;
    setState(() {
      range = choice.clear ? null : choice.range;
      final ids = visible.map((r) => r.id).toSet();
      selectedIds.removeWhere((id) => !ids.contains(id));
      if (!ids.contains(previewId)) previewId = null;
    });
  }

  Future<void> printSelected({required bool summary}) async {
    final records = demoZReadings.where((r) => selectedIds.contains(r.id)).toList();
    if (records.isEmpty || busy) return;
    setState(() => busy = true);
    try {
      if (summary) {
        await ReportPrinting.printZReadingSummary(records);
      } else {
        await ReportPrinting.reprintZReadings(records);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to open print dialog: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget statLine(String label, String value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: strong ? ink : muted, fontSize: 12, fontWeight: strong ? FontWeight.w600 : FontWeight.w400))),
      const SizedBox(width: 16),
      Text(value, style: TextStyle(color: ink, fontSize: strong ? 15 : 12, fontWeight: strong ? FontWeight.w700 : FontWeight.w600)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final list = visible;
    final selected = currentPreview;
    final windowWidth = MediaQuery.sizeOf(context).width;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1040, maxHeight: MediaQuery.sizeOf(context).height * .85),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Past Z-Readings', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: ink)),
                SizedBox(height: 4),
                Text('Select days to reprint or prepare a combined summary.', style: TextStyle(fontSize: 12, color: muted)),
              ])),
              IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, size: 20)),
            ]),
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: const Color(0xFFF3F6E8), borderRadius: BorderRadius.circular(10)),
              child: const Text('DEMO HISTORY · Sample reports only. Reprints do not create new Z-numbers or close a fiscal day.', style: TextStyle(fontSize: 11, color: ink)),
            ),
            const SizedBox(height: 13),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              OutlinedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 15),
                label: Text(range == null ? 'All dates' : '${zDate(range!.start)} – ${zDate(range!.end)}'),
              ),
              if (range != null) TextButton(onPressed: () => setState(() { range = null; }), child: const Text('Clear filter')),
              OutlinedButton(
                onPressed: list.isEmpty ? null : () => setState(() {
                  final ids = list.map((r) => r.id).toSet();
                  if (ids.every(selectedIds.contains)) { selectedIds.removeAll(ids); } else { selectedIds.addAll(ids); }
                }),
                child: Text(list.isNotEmpty && list.every((r) => selectedIds.contains(r.id)) ? 'Deselect all' : 'Select all visible'),
              ),
              Text('${selectedIds.length} selected', style: const TextStyle(fontSize: 12, color: muted)),
            ]),
            const SizedBox(height: 12),
            Expanded(child: LayoutBuilder(builder: (context, constraints) {
              final split = constraints.maxWidth > 610 && windowWidth > 740;
              final historyList = Container(
                decoration: BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(12)),
                child: list.isEmpty
                  ? const Center(child: Text('No sample Z-Readings for this date range.', style: TextStyle(color: muted, fontSize: 12)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: line),
                      itemBuilder: (context, i) {
                        final r = list[i];
                        final active = (previewId ?? list.first.id) == r.id;
                        return Material(
                          color: active ? const Color(0xFFF1F5E8) : Colors.white,
                          child: InkWell(
                            onTap: () => setState(() => previewId = r.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                              child: Row(children: [
                                Checkbox(
                                  value: selectedIds.contains(r.id),
                                  activeColor: ink,
                                  checkColor: lime,
                                  onChanged: (on) => setState(() { if (on == true) { selectedIds.add(r.id); } else { selectedIds.remove(r.id); } }),
                                ),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(zDate(r.date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ink)),
                                  const SizedBox(height: 3),
                                  Text('Z #${r.id} · ${r.counter} · ${r.transactions} sales', style: const TextStyle(fontSize: 10, color: muted)),
                                ])),
                                Text(zMoney(r.net), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ink)),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
              );
              final preview = Container(
                decoration: BoxDecoration(color: const Color(0xFFFAFAF8), border: Border.all(color: line), borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(17),
                child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Z-READING PREVIEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted)),
                  const SizedBox(height: 9),
                  Text(zDate(selected.date), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ink)),
                  Text('Z #${selected.id} · ${selected.counter}', style: const TextStyle(fontSize: 11, color: muted)),
                  const SizedBox(height: 13),
                  const Divider(color: line),
                  statLine('First invoice', selected.openingInvoice),
                  statLine('Last invoice', selected.closingInvoice),
                  statLine('Transactions', '${selected.transactions}'),
                  const Divider(color: line),
                  statLine('Gross sales', zMoney(selected.gross)),
                  statLine('Discounts', '−${zMoney(selected.discounts)}'),
                  statLine('Refunds', '−${zMoney(selected.refunds)}'),
                  const Divider(color: line),
                  statLine('Net sales', zMoney(selected.net), strong: true),
                  statLine('Cash', zMoney(selected.cash)),
                  statLine('Other payments', zMoney(selected.otherPayments)),
                  const SizedBox(height: 11),
                  const Text('Demo only. Additional BIR fiscal fields will come from the registered POS ledger.', style: TextStyle(fontSize: 10, color: muted)),
                ])),
              );
              if (!split) return Column(children: [Expanded(flex: 3, child: historyList), const SizedBox(height: 10), Expanded(flex: 2, child: preview)]);
              return Row(children: [Expanded(flex: 6, child: historyList), const SizedBox(width: 14), Expanded(flex: 4, child: preview)]);
            })),
            const SizedBox(height: 14),
            Wrap(spacing: 9, runSpacing: 8, alignment: WrapAlignment.end, children: [
              OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
              OutlinedButton.icon(
                onPressed: selectedIds.isEmpty || busy ? null : () => printSelected(summary: true),
                icon: const Icon(Icons.summarize_outlined, size: 17),
                label: const Text('Print combined summary'),
              ),
              FilledButton.icon(
                onPressed: selectedIds.isEmpty || busy ? null : () => printSelected(summary: false),
                icon: const Icon(Icons.print_outlined, size: 17),
                label: Text(busy ? 'Opening print…' : 'Reprint selected Z-Readings'),
                style: FilledButton.styleFrom(backgroundColor: ink, foregroundColor: lime),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
