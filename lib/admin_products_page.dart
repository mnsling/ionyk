import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'ionyk_api.dart';

/// IONYK Systems — database-backed Products and staged price changes.
class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});
  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _Product {
  _Product(this.barcode, this.name, this.category, this.cost, this.price,
      this.supplier, this.stock,
      {this.previousPrice, this.previousCasePrice, this.unitsPerCase = 1,
      this.caseBarcode = '', this.sellingUnits = 'piece',
      double? caseCost, double? casePrice, this.productId})
      : caseCost = caseCost ?? cost * unitsPerCase,
        casePrice = casePrice ?? price * unitsPerCase;

  final String barcode;
  final int? productId;
  String name;
  String category;
  double cost; // normalized supplier cost per individual piece
  double price; // selling price per individual piece
  double caseCost; // supplier cost for a full case
  double casePrice; // selling price for a full case
  String caseBarcode;
  String sellingUnits; // 'piece', 'case', 'both'
  int unitsPerCase;
  double? previousPrice;
  double? previousCasePrice; // prior published case selling price
  String supplier;
  final int stock; // inventory base unit is pieces, not cases

  _Product copy() => _Product(barcode, name, category, cost, price,
      supplier, stock, previousPrice: previousPrice,
      previousCasePrice: previousCasePrice,
      unitsPerCase: unitsPerCase, caseBarcode: caseBarcode,
      sellingUnits: sellingUnits, caseCost: caseCost, casePrice: casePrice, productId: productId);

  String get packagingLabel => switch (sellingUnits) {
    'both' => 'Piece + Case',
    'case' => 'Case only',
    _ => 'Piece only',
  };
}

class _PendingProduct {
  _PendingProduct(this.product, {required this.isNew, required this.description, this.draftId});
  final int? draftId;
  _Product product;
  final bool isNew;
  String description;
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  static const ink = Color(0xFF171B1C);
  static const muted = Color(0xFF66716C);
  static const lime = Color(0xFFD9FF57);
  static const border = Color(0xFFE1E6E0);
  static const soft = Color(0xFFF3F5F1);
  final search = TextEditingController();
  final tableHorizontalScroll = ScrollController();
  String? selectedProductBarcode;
  String query = '';
  // Prototype staging area. None of these records is visible to the
  // published catalogue until Publish is pressed.
  final Map<String, _PendingProduct> pending = {};
  final IonykApi api = const IonykApi();
  final products = <_Product>[];
  bool loading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    refreshFromDatabase();
  }

  double _asDouble(Object? v) => double.tryParse('$v') ?? 0;
  int _asInt(Object? v) => int.tryParse('$v') ?? 0;
  String _asString(Object? v) => v?.toString() ?? '';

  _Product _draftProduct(Map<String, dynamic> data, {int? productId}) {
    final cost = _asDouble(data['supplier_cost_per_piece']);
    final price = _asDouble(data['piece_price']);
    final quantity = _asInt(data['pieces_per_case']);
    final qty = quantity < 1 ? 1 : quantity;
    return _Product(
      _asString(data['piece_barcode']),
      _asString(data['description']),
      _asString(data['category']),
      cost, price, _asString(data['supplier']), 0,
      unitsPerCase: qty,
      caseBarcode: _asString(data['case_barcode']),
      sellingUnits: _asString(data['selling_units']).isEmpty ? 'piece' : _asString(data['selling_units']),
      casePrice: data['case_price'] == null ? price * qty : _asDouble(data['case_price']),
      productId: productId,
    );
  }

  Map<String, dynamic> _payload(_ProductFormResult form, String barcode) => {
    'description': form.name,
    'piece_barcode': barcode,
    'supplier_cost_per_piece': form.pieceCost,
    'piece_price': form.piecePrice,
    'category': form.category,
    'supplier': form.supplier,
    'case_barcode': form.caseBarcode,
    'case_price': form.casePrice,
    'pieces_per_case': form.piecesPerCase,
    'selling_units': form.sellingUnits,
  };

  Future<void> refreshFromDatabase() async {
    if (mounted) setState(() { loading = true; loadError = null; });
    try {
      final results = await Future.wait([api.publishedProducts(), api.pendingDrafts()]);
      final published = <_Product>[];
      for (final row in results[0]) {
        final unit = row['sell_case'] == true
            ? (row['sell_piece'] == true ? 'both' : 'case') : 'piece';
        final qty = _asInt(row['pieces_per_case']);
        published.add(_Product(
          _asString(row['piece_barcode']), _asString(row['description']),
          _asString(row['category']), _asDouble(row['supplier_cost_per_piece']),
          _asDouble(row['piece_price']), _asString(row['supplier']), 0,
          unitsPerCase: qty < 1 ? 1 : qty,
          caseBarcode: _asString(row['case_barcode']),
          sellingUnits: unit,
          casePrice: _asDouble(row['case_price']),
          productId: _asInt(row['id']),
        ));
      }
      final staged = <String, _PendingProduct>{};
      for (final row in results[1]) {
        final raw = row['proposed_data'];
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final product = _draftProduct(data, productId: row['product_id'] == null ? null : _asInt(row['product_id']));
        if (product.barcode.isEmpty) continue;
        staged[product.barcode] = _PendingProduct(product,
          isNew: row['action'] == 'create',
          description: row['action'] == 'create' ? 'New product' : 'Product update',
          draftId: _asInt(row['id']),
        );
      }
      if (!mounted) return;
      setState(() {
        products..clear()..addAll(published);
        pending..clear()..addAll(staged);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; loadError = e.toString(); });
      message('Could not load products: $e');
    }
  }

  @override
  void dispose() { search.dispose(); tableHorizontalScroll.dispose(); super.dispose(); }

  String money(num value) => '₱${value.toStringAsFixed(2)}';
  double change(_Product p) => p.previousPrice == null || p.previousPrice == 0
      ? 0 : (p.price - p.previousPrice!) / p.previousPrice! * 100;
  String changeLabel(double current, double? previous) {
    if (previous == null || previous <= 0) return '—';
    final pct = (current - previous) / previous * 100;
    return '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(2)}%';
  }
  Color changeColor(double current, double? previous) {
    if (previous == null || previous <= 0) return muted;
    return current > previous ? const Color(0xFF286A48)
        : current < previous ? const Color(0xFFB34141) : muted;
  }
  double markup(_Product p) => p.cost <= 0 ? 0 : (p.price - p.cost) / p.cost * 100;
  void message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  Widget surface(Widget child, {EdgeInsets padding = const EdgeInsets.all(20)}) =>
      Container(padding: padding, decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: border)), child: child);

  Widget summary(String label, String value, String sub, {bool accent = false}) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: accent ? lime : Colors.white,
        border: Border.all(color: accent ? lime : border), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: muted)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink)),
        const SizedBox(height: 3),
        Text(sub, style: const TextStyle(fontSize: 10, color: muted)),
      ])));

  Widget _tableCell(Widget child, {bool header = false, String? barcode}) =>
    barcode == null
      ? Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: header ? 14 : 17),
          child: child)
      : InkWell(
          onTap: () => setState(() => selectedProductBarcode = barcode),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: header ? 14 : 17),
            child: child));

  bool barcodeTaken(String code, {String? exceptProductBarcode}) {
    if (code.trim().isEmpty) return false;
    for (final p in [...products, ...pending.values.map((d) => d.product)]) {
      if (p.barcode == exceptProductBarcode) continue;
      if (p.barcode == code || p.caseBarcode == code) return true;
    }
    return false;
  }

  Future<void> edit(_Product product) async {
    final staged = pending[product.barcode];
    final current = staged?.product ?? product;
    final updated = await showDialog<_ProductFormResult>(
      context: context, builder: (_) => _ProductForm(product: current));
    if (!mounted || updated == null) return;
    if (updated.caseBarcode.isNotEmpty &&
        (updated.caseBarcode == product.barcode ||
         barcodeTaken(updated.caseBarcode, exceptProductBarcode: product.barcode))) {
      message('Case barcode must be unique and different from the piece barcode.');
      return;
    }
    try {
      if (staged?.draftId != null) {
        await api.updateProductDraft(staged!.draftId!, _payload(updated, product.barcode));
      } else if (product.productId != null) {
        await api.createPublishedEditDraft(product.productId!, _payload(updated, product.barcode));
      } else {
        message('Cannot edit: missing database product ID.');
        return;
      }
      await refreshFromDatabase();
      if (mounted) message('Product changes saved as a pending draft. Publish to apply.');
    } catch (e) {
      if (mounted) message('Could not save product changes: $e');
    }
  }

  Future<void> addProduct() async {
    final updated = await showDialog<_ProductFormResult>(
      context: context, builder: (_) => const _ProductForm());
    if (!mounted || updated == null) return;
    final barcode = updated.barcode.trim();
    if (barcodeTaken(barcode) ||
        (updated.caseBarcode.isNotEmpty &&
         (updated.caseBarcode == barcode || barcodeTaken(updated.caseBarcode)))) {
      message('Barcode is already assigned to a product or case.');
      return;
    }
    try {
      await api.createProductDraft(_payload(updated, barcode));
      await refreshFromDatabase();
      if (mounted) message('Product draft saved to PostgreSQL.');
    } catch (e) {
      if (mounted) message('Could not save draft: $e');
    }
  }

  Future<void> publishPending() async {
    final drafts=pending.values.where((p)=>p.draftId != null).toList();
    if (drafts.isEmpty) { message('No pending drafts to publish'); return; }
    try {
      final counters=(await api.terminals()).where((r)=>r['is_active']==true).toList();
      if (!mounted) return;
      if (counters.isEmpty) { message('Add an active counter in Settings first'); return; }
      final selected=<int>{for (final c in counters) c['id'] as int};
      final approved=await showDialog<bool>(context:context,builder:(dialogContext)=>StatefulBuilder(
        builder:(ctx,refresh)=>AlertDialog(
          title:const Text('Publish to POS'),
          content:SizedBox(width:400,child:Column(mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Publish ${drafts.length} pending product(s) to:'),
            const SizedBox(height:12),
            ...counters.map((c)=>CheckboxListTile(
              title:Text('${c['label']} · ${c['display_name']??''}'),
              value:selected.contains(c['id']),
              onChanged:(v)=>refresh(() {if (v==true) {selected.add(c['id'] as int);} else {selected.remove(c['id']);}}),
              controlAffinity:ListTileControlAffinity.leading,
              dense:true,
            )),
          ])),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
            FilledButton(onPressed:selected.isEmpty?null:()=>Navigator.pop(ctx,true),child:const Text('Publish'))],
        )));
      if (approved!=true || !mounted) return;
      await api.publishDrafts(drafts.map((p)=>p.draftId!).toList(),selected.toList());
      await refreshFromDatabase();
      if (mounted) message('Products published to ${selected.length} counter(s). Sign in again to refresh POS.');
    } catch (e) { if (mounted) message('Could not publish: $e'); }
  }

  Future<void> discardPending(String barcode) async {
    final staged = pending[barcode];
    if (staged?.draftId == null) {
      message('Draft not found.');
      return;
    }
    try {
      await api.discardProductDraft(staged!.draftId!);
      await refreshFromDatabase();
      if (mounted) message('Draft discarded in PostgreSQL.');
    } catch (e) {
      if (mounted) message('Could not discard draft: $e');
    }
  }

  // Dark, compact staging panel inspired by the IONYK live-counters card.
  // The list scrolls independently; the publish action stays visible.
  Widget pendingChangesCard() {
    final entries = pending.values.toList();
    final newCount = entries.where((e) => e.isNew).length;
    final editedCount = entries.length - newCount;
    const panel = Color(0xFF151B1A);
    const subdued = Color(0xFFABB8B0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Pending changes',
            style: TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF2B3431),
              borderRadius: BorderRadius.circular(30)),
            child: Text('${entries.length} pending',
              style: const TextStyle(color: lime, fontSize: 10,
                fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 7),
        const Text('New products and edits awaiting approval',
          style: TextStyle(color: subdued, fontSize: 11)),
        const SizedBox(height: 17),
        Row(children: [
          Expanded(child: _draftCounter('$newCount', 'New', lime)),
          const SizedBox(width: 9),
          Expanded(child: _draftCounter('$editedCount', 'Edited',
            const Color(0xFFD3DBD6))),
        ]),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFF35403A)),
        const SizedBox(height: 12),
        Expanded(
          child: entries.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 28, color: subdued),
                  SizedBox(height: 10),
                  Text('Nothing to publish',
                    style: TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w600)),
                  SizedBox(height: 5),
                  Text('Add a product or edit a published item.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subdued, fontSize: 10)),
                ]))
            : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(
                  color: Color(0xFF35403A), height: 17),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final p = entry.product;
                  final publishedIndex = products.indexWhere(
                    (item) => item.barcode == p.barcode);
                  final oldProduct = publishedIndex < 0
                    ? null : products[publishedIndex];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 25, height: 25, alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF29342E),
                          borderRadius: BorderRadius.circular(7)),
                        child: Text('${index + 1}',
                          style: const TextStyle(fontSize: 11, color: lime,
                            fontWeight: FontWeight.w700))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(p.name, maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white,
                                fontSize: 12, fontWeight: FontWeight.w600))),
                            const SizedBox(width: 6),
                            Text(entry.isNew ? 'NEW' : 'EDITED',
                              style: TextStyle(color: entry.isNew ? lime : subdued,
                                fontSize: 9, fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 3),
                          Text(p.barcode, maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: subdued)),
                          const SizedBox(height: 4),
                          Text(p.packagingLabel, style: const TextStyle(color: subdued, fontSize: 10)),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  '${p.sellingUnits == 'case' ? 'Case' : 'Piece'} ${money(p.sellingUnits == 'case' ? p.casePrice : p.price)}${oldProduct == null ? '' : ' · Was ${money(oldProduct.sellingUnits == 'case' ? oldProduct.casePrice : oldProduct.price)}'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: lime),
                                ),
                              ),
                              const SizedBox(width: 6),
                              TextButton(
                                onPressed: () => edit(p),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 7),
                                ),
                                child: const Text('Edit', style: TextStyle(fontSize: 11)),
                              ),
                              TextButton(
                                onPressed: () => discardPending(p.barcode),
                                style: TextButton.styleFrom(
                                  foregroundColor: subdued,
                                  minimumSize: const Size(0, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                ),
                                child: const Text('Discard', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ])),
                    ]),
                  );
                },
              ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFF35403A)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 43,
          child: FilledButton.icon(
            onPressed: pending.isEmpty ? null : publishPending,
            icon: const Icon(Icons.publish_rounded, size: 16),
            label: const Text('Publish to POS',
              style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: lime,
              foregroundColor: ink,
              disabledBackgroundColor: const Color(0xFF35403A),
              disabledForegroundColor: subdued,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
          )),
        const SizedBox(height: 9),
        const Text('Select target counters before publishing',
          style: TextStyle(color: subdued, fontSize: 9),
          textAlign: TextAlign.left),
      ]),
    );
  }

  Widget _draftCounter(String number, String label, Color tint) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF27312C),
        borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(number, style: TextStyle(color: tint, fontSize: 20,
          fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Color(0xFFABB8B0),
          fontSize: 10)),
      ]),
    );

  Widget _statusLabel(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
    child: Text(label, style: TextStyle(fontSize: 10,
      fontWeight: FontWeight.w700, color: fg)));

  void importPreview() => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    title: const Text('Import products from Excel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
    content: const SizedBox(width: 410, child: Text(
      'This is a placeholder until you obtain the old POS Excel export.\n\n'
      'Planned: choose .xlsx/.csv → map unknown columns → match by barcode or product ID → preview price and stock changes → approve import.',
      style: TextStyle(fontSize: 12, height: 1.8))),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
  ));

  Widget publishedCatalogue(List<_Product> matches) =>
    surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Published catalogue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          Text('${matches.length} results', style: const TextStyle(color: muted, fontSize: 11)),
        ]),
        const SizedBox(height: 5),
        const Text('Click a row to highlight it. Scroll sideways to see all columns.',
          style: TextStyle(fontSize: 10, color: muted)),
        const SizedBox(height: 12),
        TextField(controller: search, onChanged: (v) => setState(() => query = v),
          style: const TextStyle(fontSize: 12, color: ink),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: muted),
            hintText: 'Search product, barcode, category or supplier',
            hintStyle: const TextStyle(fontSize: 12, color: muted),
            suffixIcon: query.isEmpty ? null : IconButton(tooltip: 'Clear search',
              icon: const Icon(Icons.close, size: 17),
              onPressed: () { search.clear(); setState(() => query = ''); }),
            isDense: true, filled: true, fillColor: soft,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide.none),
          )),
        const SizedBox(height: 15),
        // Keep the horizontal scroll viewport as tall as the entire remaining
        // catalogue area. This anchors its scrollbar to the card bottom, not
        // to the header row. The inner body gets its own vertical scrolling.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: Scrollbar(
                controller: tableHorizontalScroll,
                thumbVisibility: true,
                trackVisibility: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: tableHorizontalScroll,
                  scrollDirection: Axis.horizontal,
                  // Full height allows dragging the empty white area to pan.
                  child: SizedBox(
                    width: constraints.maxWidth < 1680
                        ? 1680
                        : constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Column(
                      children: [
                        Table(
                          columnWidths: const {
                  0: FixedColumnWidth(58),
                  1: FixedColumnWidth(260),
                  2: FixedColumnWidth(145),
                  3: FixedColumnWidth(125),
                  4: FixedColumnWidth(140),
                  5: FixedColumnWidth(145),
                  6: FixedColumnWidth(130),
                  7: FixedColumnWidth(115),
                  8: FixedColumnWidth(140),
                  9: FixedColumnWidth(140),
                  10: FixedColumnWidth(165),
                  11: FixedColumnWidth(100),
                },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                    decoration: const BoxDecoration(color: soft),
                    children: [
                      for (final title in [
                        '#', 'PRODUCT / BARCODE', 'SELLING UNITS', 'COST / PC', 'PRICE / PC',
                        'PRICE / CASE', 'MARKUP / PC', 'PCS / CASE',
                        'PIECE CHANGE', 'CASE CHANGE', 'SUPPLIER', 'ACTION'
                      ])
                        _tableCell(Text(title, style: const TextStyle(
                          fontSize: 10, color: muted, fontWeight: FontWeight.w700)),
                          header: true),
                    ],
                  ),
                          ],
                        ),
                        Expanded(
                          child: matches.isEmpty
                              ? const SizedBox.expand()
                              : SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: Table(
                                    columnWidths: const {
                  0: FixedColumnWidth(58),
                  1: FixedColumnWidth(260),
                  2: FixedColumnWidth(145),
                  3: FixedColumnWidth(125),
                  4: FixedColumnWidth(140),
                  5: FixedColumnWidth(145),
                  6: FixedColumnWidth(130),
                  7: FixedColumnWidth(115),
                  8: FixedColumnWidth(140),
                  9: FixedColumnWidth(140),
                  10: FixedColumnWidth(165),
                  11: FixedColumnWidth(100),
                },
                                    defaultVerticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    children: [
                                      for (var rowIndex = 0; rowIndex < matches.length; rowIndex++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: selectedProductBarcode == matches[rowIndex].barcode
                          ? const Color(0xFFF0F8DE) : Colors.white,
                        border: const Border(bottom: BorderSide(color: border))),
                      children: [
                        _tableCell(Text('${rowIndex + 1}', style: const TextStyle(
                          color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
                          barcode: matches[rowIndex].barcode),
                        _tableCell(Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(matches[rowIndex].name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(matches[rowIndex].barcode, style: const TextStyle(fontSize: 10, color: muted)),
                          ],
                        ), barcode: matches[rowIndex].barcode),
                        _tableCell(Text(matches[rowIndex].packagingLabel, style: const TextStyle(fontSize: 10)), barcode: matches[rowIndex].barcode),
                        _tableCell(Text(money(matches[rowIndex].cost), style: const TextStyle(fontSize: 11)), barcode: matches[rowIndex].barcode),
                        _tableCell(Text(matches[rowIndex].sellingUnits == 'case' ? '—' : money(matches[rowIndex].price),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), barcode: matches[rowIndex].barcode),
                        _tableCell(Text(matches[rowIndex].sellingUnits == 'piece' ? '—' : money(matches[rowIndex].casePrice),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), barcode: matches[rowIndex].barcode),
                        _tableCell(Text(matches[rowIndex].sellingUnits == 'case' ? '—' : '${markup(matches[rowIndex]).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 11)), barcode: matches[rowIndex].barcode),
                        _tableCell(Text('${matches[rowIndex].unitsPerCase}', style: const TextStyle(fontSize: 11)), barcode: matches[rowIndex].barcode),
                        _tableCell(Text(
                          matches[rowIndex].sellingUnits == 'case' ? '—' :
                            changeLabel(matches[rowIndex].price, matches[rowIndex].previousPrice),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: changeColor(matches[rowIndex].price, matches[rowIndex].previousPrice))),
                          barcode: matches[rowIndex].barcode),
                        _tableCell(Text(
                          matches[rowIndex].sellingUnits == 'piece' ? '—' :
                            changeLabel(matches[rowIndex].casePrice, matches[rowIndex].previousCasePrice),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: changeColor(matches[rowIndex].casePrice, matches[rowIndex].previousCasePrice))),
                          barcode: matches[rowIndex].barcode),
                        _tableCell(Text(matches[rowIndex].supplier, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)), barcode: matches[rowIndex].barcode),
                        _tableCell(SizedBox(
                          width: 64,
                          child: OutlinedButton(
                            onPressed: () => edit(matches[rowIndex]),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 9),
                              minimumSize: const Size(62, 34),
                              foregroundColor: ink,
                              side: const BorderSide(color: border),
                              visualDensity: VisualDensity.compact),
                            child: const Text('Edit', softWrap: false,
                              style: TextStyle(fontSize: 11)),
                          ),
                        ), barcode: matches[rowIndex].barcode),
                      ],
                    ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                ))),
                if (matches.isEmpty)
                  const Positioned.fill(
                    top: 42, // below the catalogue column headings
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          'No products found.',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ]));

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (loadError != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Unable to connect to IONYK API.'),
        const SizedBox(height: 8),
        Text(loadError!, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        FilledButton(onPressed: refreshFromDatabase, child: const Text('Retry')),
      ]));
    }
    final matches = products.where((p) =>
      '${p.name} ${p.barcode} ${p.category} ${p.supplier}'.toLowerCase().contains(query.toLowerCase())).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Products', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, letterSpacing: -.6)),
          SizedBox(height: 5),
          Text('One product, with piece and case pricing in one catalogue.', style: TextStyle(color: muted, fontSize: 11)),
        ])),
        SizedBox(height: 40, child: OutlinedButton.icon(
          onPressed: importPreview,
          icon: const Icon(Icons.upload_file_outlined, size: 16),
          label: const Text('Import Excel'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            foregroundColor: ink, backgroundColor: Colors.white,
            side: const BorderSide(color: border),
            textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        )),
        const SizedBox(width: 10),
        SizedBox(height: 40, child: FilledButton.icon(
          onPressed: addProduct,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Product'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            backgroundColor: ink, foregroundColor: lime,
            textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        )),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        summary('Published products', '${products.length}', 'Local catalogue'), const SizedBox(width: 12),
        summary('Pending changes', '${pending.length}', 'Awaiting publication', accent: true), const SizedBox(width: 12),
        summary('Suppliers', '${products.map((p) => p.supplier).toSet().length}', 'Across the catalogue'),
      ]),
      const SizedBox(height: 15),
      LayoutBuilder(builder: (context, constraints) {
        // Both cards share one height, whether displayed side-by-side or stacked.
        // Each card scrolls its own content without growing the outer layout.
        const double panelHeight = 620;
        final wide = constraints.maxWidth >= 1020;
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: SizedBox(
              height: panelHeight, child: pendingChangesCard())),
            const SizedBox(width: 14),
            Expanded(flex: 7, child: SizedBox(
              height: panelHeight, child: publishedCatalogue(matches))),
          ]);
        }
        return Column(children: [
          SizedBox(height: panelHeight, child: pendingChangesCard()),
          const SizedBox(height: 14),
          SizedBox(height: panelHeight, child: publishedCatalogue(matches)),
        ]);
      }),
      const SizedBox(height: 12),
      const Text('DEMO ONLY: publication updates this screen in memory, not any cashier terminal. Changes disappear on restart.', style: TextStyle(fontSize: 10, color: muted)),
    ]);
  }
}


/// Values returned from Add / Edit. The canonical inventory unit is a piece.
class _ProductFormResult {
  const _ProductFormResult({required this.barcode, required this.name,
    required this.category, required this.supplier, required this.caseBarcode,
    required this.sellingUnits, required this.piecesPerCase,
    required this.pieceCost, required this.caseCost,
    required this.piecePrice, required this.casePrice});
  final String barcode, name, category, supplier, caseBarcode, sellingUnits;
  final int piecesPerCase;
  final double pieceCost, caseCost, piecePrice, casePrice;
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({this.product});
  final _Product? product;
  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  static const ink = Color(0xFF171B1C);
  static const muted = Color(0xFF66716C);
  static const lime = Color(0xFFD9FF57);
  static const soft = Color(0xFFF3F5F1);
  final formKey = GlobalKey<FormState>();
  final barcode = TextEditingController();
  final caseBarcode = TextEditingController();
  final name = TextEditingController();
  final category = TextEditingController();
  final supplier = TextEditingController();
  final count = TextEditingController(text: '12');
  final cost = TextEditingController();
  final piecePrice = TextEditingController();
  final pieceMarkup = TextEditingController();
  final casePrice = TextEditingController();
  final caseMarkup = TextEditingController();
  String units = 'both';
  bool syncing = false;

  _Product? get original => widget.product;
  int get quantity => int.tryParse(count.text) ?? 1;
  int get safeQty => quantity > 0 ? quantity : 1;
  // Supplier cost is always entered per piece. Switching selling units never
  // changes the underlying cost; case cost is just pieces × piece cost.
  double get costPerPiece => double.tryParse(cost.text) ?? original?.cost ?? 0;
  int get effectiveQty => caseEnabled ? safeQty : 1;
  double get costPerCase => costPerPiece * effectiveQty;
  double get sellingPiece => double.tryParse(piecePrice.text) ?? original?.price ?? 0;
  double get sellingCase => double.tryParse(casePrice.text) ??
      (original == null ? 0 : original!.sellingUnits == 'piece'
        ? sellingPiece * safeQty : original!.casePrice);
  double get piecePct => costPerPiece > 0 ? (sellingPiece / costPerPiece - 1) * 100 : 0;
  double get casePct => costPerCase > 0 ? (sellingCase / costPerCase - 1) * 100 : 0;
  bool get pieceEnabled => units != 'case';
  bool get caseEnabled => units != 'piece';

  @override
  void initState() {
    super.initState();
    final p = original;
    if (p != null) {
      barcode.text = p.barcode;
      caseBarcode.text = p.caseBarcode;
      name.text = p.name;
      category.text = p.category;
      supplier.text = p.supplier;
      count.text = (p.unitsPerCase < 2 ? 12 : p.unitsPerCase).toString();
      units = p.sellingUnits;
    }
    cost.addListener(_costOrCountChanged);
    count.addListener(_costOrCountChanged);
    piecePrice.addListener(() => _priceChanged(false));
    casePrice.addListener(() => _priceChanged(true));
    pieceMarkup.addListener(() => _markupChanged(false));
    caseMarkup.addListener(() => _markupChanged(true));
  }

  void _priceChanged(bool isCase) {
    if (syncing) return;
    syncing = true;
    final val = double.tryParse((isCase ? casePrice : piecePrice).text);
    final basis = isCase ? costPerCase : costPerPiece;
    final target = isCase ? caseMarkup : pieceMarkup;
    target.text = val == null || basis <= 0 ? '' :
      ((val - basis) / basis * 100).toStringAsFixed(2);
    syncing = false;
    if (mounted) setState(() {});
  }

  void _markupChanged(bool isCase) {
    if (syncing) return;
    syncing = true;
    final pct = double.tryParse((isCase ? caseMarkup : pieceMarkup).text);
    final basis = isCase ? costPerCase : costPerPiece;
    final target = isCase ? casePrice : piecePrice;
    target.text = pct == null || basis <= 0 ? '' :
      (basis * (1 + pct / 100)).toStringAsFixed(2);
    syncing = false;
    if (mounted) setState(() {});
  }

  void _costOrCountChanged() {
    if (syncing) return;
    // Maintain entered markup when capital changes; otherwise recalculate markup
    // from the directly entered price.
    if (pieceMarkup.text.isNotEmpty) {
      _markupChanged(false);
    } else if (piecePrice.text.isNotEmpty) {
      _priceChanged(false);
    }
    if (caseMarkup.text.isNotEmpty) {
      _markupChanged(true);
    } else if (casePrice.text.isNotEmpty) {
      _priceChanged(true);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [barcode, caseBarcode, name, category, supplier,
      count, cost, piecePrice, pieceMarkup, casePrice, caseMarkup]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration deco(String title, String hint) => InputDecoration(
    labelText: title, hintText: hint, filled: true, fillColor: soft,
    labelStyle: const TextStyle(fontSize: 12, color: muted),
    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
      borderSide: BorderSide.none),
  );
  String? requiredField(String? s) => (s ?? '').trim().isEmpty ? 'Required' : null;
  String? moneyField(String? s, {bool optional = false}) {
    if (optional && (s ?? '').trim().isEmpty) return null;
    final value = double.tryParse(s ?? '');
    return value == null || !value.isFinite || value < 0
        ? 'Enter a valid nonnegative amount' : null;
  }
  String money(double amount) => '₱${amount.toStringAsFixed(2)}';
  Widget gap([double amount = 12]) => SizedBox(height: amount);

  Widget priceEditor({required bool isCase}) {
    final enabled = isCase ? caseEnabled : pieceEnabled;
    final controller = isCase ? casePrice : piecePrice;
    final markupController = isCase ? caseMarkup : pieceMarkup;
    final old = original;
    final previousPrice = old == null ? '' :
      (isCase && old.sellingUnits == 'piece'
        ? (old.price * safeQty) : isCase ? old.casePrice : old.price)
        .toStringAsFixed(2);
    final previousMarkup = old == null ? '' :
      ((isCase ? costPerCase : old.cost) > 0
        ? ((isCase ? ((old.sellingUnits == 'piece' ? old.price * safeQty : old.casePrice) / costPerCase) : old.price / old.cost) - 1) * 100
        : 0).toStringAsFixed(2);
    return Opacity(opacity: enabled ? 1 : .45,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isCase ? 'CASE SELLING PRICE' : 'PIECE SELLING PRICE',
          style: const TextStyle(fontSize: 11, color: ink,
            fontWeight: FontWeight.w700)),
        gap(7),
        Row(children: [
          Expanded(child: TextFormField(
            enabled: enabled, controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: deco('Selling price (₱)', previousPrice.isEmpty ? '0.00' : previousPrice),
            validator: (s) => enabled && original == null ? moneyField(s) : moneyField(s, optional: true))),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(
            enabled: enabled, controller: markupController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: deco('Markup (%)', previousMarkup.isEmpty ? '0.00' : previousMarkup),
            validator: (s) {
              if (!enabled || (s ?? '').isEmpty) return null;
              final v = double.tryParse(s!);
              return v == null || !v.isFinite || v < -100 ? 'Invalid markup' : null;
            })),
        ]),
      ]));
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;
    final parsedCost = double.tryParse(cost.text);
    if (original == null && (parsedCost == null || parsedCost < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the supplier cost.')));
      return;
    }
    final qty = effectiveQty;
    if (caseEnabled && qty < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A case must contain at least 2 pieces.')));
      return;
    }
    if (caseBarcode.text.trim().isNotEmpty &&
        caseBarcode.text.trim() == barcode.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Case and piece barcodes must differ.')));
      return;
    }
    // For case-only products, normalize a per-piece reference price; for
    // piece-only products, calculate a case reference price, but do not enable it.
    final resolvedPiecePrice = pieceEnabled ? sellingPiece : sellingCase / qty;
    final resolvedCasePrice = caseEnabled ? sellingCase : sellingPiece * qty;
    Navigator.pop(context, _ProductFormResult(
      barcode: barcode.text.trim(), name: name.text.trim(),
      category: category.text.trim(), supplier: supplier.text.trim(),
      caseBarcode: caseEnabled ? caseBarcode.text.trim() : '',
      sellingUnits: units, piecesPerCase: qty,
      pieceCost: costPerPiece, caseCost: costPerCase,
      piecePrice: resolvedPiecePrice, casePrice: resolvedCasePrice,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 630, maxHeight: 790),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(key: formKey, child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(original == null ? 'Add product' : 'Edit product',
                style: const TextStyle(color: ink, fontSize: 21,
                  fontWeight: FontWeight.w700)),
              gap(5),
              const Text('Select how you sell it. Supplier cost stays per piece.',
                style: TextStyle(color: muted, fontSize: 12)),
              gap(20),
              TextFormField(controller: barcode,
                readOnly: original != null, autofocus: original == null,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                decoration: deco('Piece / primary barcode', 'Scan or type barcode'),
                validator: requiredField),
              gap(),
              TextFormField(controller: name, decoration: deco('Product description',
                'Product name'), validator: requiredField),
              gap(),
              Row(children: [
                Expanded(child: TextFormField(controller: category,
                  decoration: deco('Category (optional)', 'Snacks, drinks, etc.'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: supplier,
                  decoration: deco('Supplier (optional)', 'Supplier name'))),
              ]),
              gap(19),
              const Text('SELLING UNITS', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: ink)),
              gap(8),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'piece', label: Text('Piece only')),
                  ButtonSegment(value: 'case', label: Text('Case only')),
                  ButtonSegment(value: 'both', label: Text('Piece + Case')),
                ],
                selected: {units}, onSelectionChanged: (v) => setState(() {
                  units = v.first;
                }),
              ),
              gap(),
              if (caseEnabled) ...[
                const Text('A case is a group of pieces, not another product.',
                  style: TextStyle(fontSize: 11, color: muted)),
                gap(8),
                Row(children: [
                  Expanded(child: TextFormField(controller: count,
                    keyboardType: TextInputType.number,
                    decoration: deco('Pieces in one case', 'e.g. 12'),
                    validator: (s) => (int.tryParse(s ?? '') ?? 0) < 2
                      ? 'Enter at least 2' : null)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: caseBarcode,
                    decoration: deco('Case barcode (optional)', 'Scan case barcode'))),
                ]),
                gap(),
              ],
              const Text('SUPPLIER COST', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: ink)),
              gap(8),
              TextFormField(
                controller: cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: deco('Supplier cost per piece (₱)',
                  original == null ? '0.00' : original!.cost.toStringAsFixed(2)),
                validator: (s) => original == null ? moneyField(s) : moneyField(s, optional: true)),
              gap(9),
              if (caseEnabled) ...[
                Container(width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: soft,
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '${safeQty} pieces × ${money(costPerPiece)} = ${money(costPerCase)} per case',
                    style: const TextStyle(fontSize: 11, color: ink)),
                ),
                const SizedBox(height: 6),
                const Text('The case total is calculated. Changing selling units never changes the cost per piece.',
                  style: TextStyle(fontSize: 10, color: muted)),
              ],
              gap(19),
              priceEditor(isCase: false),
              if (caseEnabled) ...[
                gap(17),
                const Text('You can give a full case its own selling price.',
                  style: TextStyle(fontSize: 10, color: muted)),
                gap(7),
                priceEditor(isCase: true),
              ],
              gap(14),
              Container(width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: const Color(0xFFF1F6E8),
                  borderRadius: BorderRadius.circular(10)),
                child: Wrap(spacing: 22, runSpacing: 8, children: [
                  if (pieceEnabled) Text('Piece: ${money(sellingPiece)} · ${piecePct.toStringAsFixed(1)}% markup',
                    style: const TextStyle(fontSize: 11, color: ink)),
                  if (caseEnabled) Text('Case: ${money(sellingCase)} · ${casePct.toStringAsFixed(1)}% markup',
                    style: const TextStyle(fontSize: 11, color: ink)),
                ])),
              gap(19),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
                const SizedBox(width: 9),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: ink,
                    foregroundColor: lime,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
                  onPressed: submit,
                  child: Text(original == null ? 'Add to pending' : 'Save to pending'),
                ),
              ]),
            ],
          )),
        ),
      ),
    );
  }
}
