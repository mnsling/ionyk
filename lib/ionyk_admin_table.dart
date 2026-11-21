import 'package:flutter/material.dart';

/// IONYK Admin table style: the header AND every column stretch to use
/// the entire card width. A horizontal scroll appears only on narrow windows.
class IonykAdminTable extends StatefulWidget {
  const IonykAdminTable({super.key, required this.columns, required this.rows,
    this.emptyMessage = 'No records available', this.minColumnWidth = 145});
  final List<String> columns;
  final List<List<String>> rows;
  final String emptyMessage;
  final double minColumnWidth;
  @override
  State<IonykAdminTable> createState() => _IonykAdminTableState();
}

class _IonykAdminTableState extends State<IonykAdminTable> {
  final ScrollController horizontal = ScrollController();
  int? selected;
  static const ink = Color(0xFF171B1C);
  static const muted = Color(0xFF6D7772);
  static const line = Color(0xFFE0E5DF);
  static const header = Color(0xFFF2F4F0);
  @override
  void dispose() { horizontal.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    if (widget.columns.isEmpty) return const SizedBox.shrink();
    final width = box.maxWidth.isFinite ? box.maxWidth : widget.columns.length * widget.minColumnWidth;
    final tableWidth = width > widget.columns.length * widget.minColumnWidth
        ? width : widget.columns.length * widget.minColumnWidth;
    return Scrollbar(
      controller: horizontal, thumbVisibility: tableWidth > width + 1,
      child: SingleChildScrollView(
        controller: horizontal, scrollDirection: Axis.horizontal,
        child: SizedBox(width: tableWidth, child: Column(children: [
          Container(
            color: header,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: {for (var i=0;i<widget.columns.length;i++) i: const FlexColumnWidth()},
              children: [TableRow(children: [for (final h in widget.columns)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
                child: Text(h.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: muted)))])],
            ),
          ),
          if (widget.rows.isEmpty) SizedBox(height: 170, child: Center(
            child: Text(widget.emptyMessage, style: const TextStyle(fontSize: 12, color: muted)))),
          for (var index=0;index<widget.rows.length;index++)
            InkWell(onTap: ()=>setState(()=>selected=index),
              child: Container(
                decoration: BoxDecoration(
                  color: selected==index ? const Color(0xFFEAF4CF) : Colors.white,
                  border: const Border(bottom: BorderSide(color: line))),
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: {for (var i=0;i<widget.columns.length;i++) i:const FlexColumnWidth()},
                  children: [TableRow(children: [for (var j=0;j<widget.columns.length;j++)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
                      child: Text(j<widget.rows[index].length?widget.rows[index][j]:'--',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: ink)))])],
                ),
              ),
            ),
        ])),
      ),
    );
  });
}
