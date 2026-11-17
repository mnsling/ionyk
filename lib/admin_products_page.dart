import 'package:flutter/material.dart';

/// IONYK Systems — Products + Price Management preview.
/// All edits are kept in memory. There is no database or POS synchronization yet.
class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});
  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _Product {
  _Product(this.barcode, this.name, this.category, this.cost, this.price,
      this.supplier, this.stock, {this.previousPrice});
  final String barcode;
  final String name;
  final String category;
  double cost;
  double price;
  double? previousPrice;
  String supplier;
  final int stock;
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  static const ink = Color(0xFF171B1C);
  static const muted = Color(0xFF66716C);
  static const lime = Color(0xFFD9FF57);
  static const border = Color(0xFFE1E6E0);
  static const soft = Color(0xFFF3F5F1);
  final search = TextEditingController();
  String query = '';
  final products = <_Product>[
    _Product('4800012345678', 'Coca-Cola 1.5L', 'Beverages', 65, 78, 'Suysing', 124, previousPrice: 75),
    _Product('4800098765432', 'Piattos Cheese 85g', 'Snacks', 23, 30, 'Supplier B', 42, previousPrice: 28),
    _Product('4800024681357', 'Lucky Me Pancit Canton', 'Noodles', 15, 20, 'Suysing', 96, previousPrice: 20),
    _Product('4800086420357', 'Nescafé Classic 50g', 'Coffee', 63, 80, 'Supplier C', 25, previousPrice: 76),
    _Product('4800000111222', 'Nova BBQ', 'Snacks', 21, 27, 'Supplier B', 18, previousPrice: 26),
  ];

  @override
  void dispose() { search.dispose(); super.dispose(); }

  String money(num value) => '₱${value.toStringAsFixed(2)}';
  double change(_Product p) => p.previousPrice == null || p.previousPrice == 0
      ? 0 : (p.price - p.previousPrice!) / p.previousPrice! * 100;
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

  Widget _tableCell(Widget child, {bool header = false}) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: header ? 14 : 17),
    child: child,
  );

  Future<void> edit(_Product product) async {
    final result = await showDialog<_ProductEdit>(
      context: context,
      builder: (_) => _ProductEditor(product: product),
    );
    if (!mounted || result == null) return;
    setState(() {
      product.previousPrice = product.price;
      product.price = result.price;
      product.cost = result.cost;
      product.supplier = result.supplier;
    });
    message('Preview updated for ${product.name}. No real POS price was changed.');
  }

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

  @override
  Widget build(BuildContext context) {
    final matches = products.where((p) =>
      '${p.name} ${p.barcode} ${p.category} ${p.supplier}'.toLowerCase().contains(query.toLowerCase())).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Products', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, letterSpacing: -.6)),
          SizedBox(height: 5),
          Text('Product catalogue, supplier costs and price adjustments in one place.', style: TextStyle(color: muted, fontSize: 11)),
        ])),
        FilledButton.icon(onPressed: importPreview, icon: const Icon(Icons.upload_file_outlined, size: 17),
          label: const Text('Import Excel'),
          style: FilledButton.styleFrom(backgroundColor: ink, foregroundColor: lime,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)))),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        summary('Products', '${products.length}', 'Sample products'), const SizedBox(width: 12),
        summary('Price changes', '${products.where((p) => change(p).abs() > 0.001).length}', 'Compared to prior prices', accent: true), const SizedBox(width: 12),
        summary('Suppliers', '${products.map((p) => p.supplier).toSet().length}', 'Across the catalogue'),
      ]),
      const SizedBox(height: 15),
      surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Product catalogue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          Text('${matches.length} results', style: const TextStyle(color: muted, fontSize: 11)),
        ]),
        const SizedBox(height: 14),
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
        LayoutBuilder(builder: (context, constraints) =>
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: constraints.maxWidth < 900 ? 900 : constraints.maxWidth,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(3.0),
                  1: FlexColumnWidth(1.1),
                  2: FlexColumnWidth(1.4),
                  3: FlexColumnWidth(1.4),
                  4: FlexColumnWidth(1.0),
                  5: FlexColumnWidth(1.6),
                  6: FlexColumnWidth(1.0),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: soft),
                    children: [
                      for (final title in [
                        'PRODUCT / BARCODE', 'CAPITAL', 'SELLING PRICE',
                        'PRICE CHANGE', 'MARKUP', 'SUPPLIER', 'ACTION'
                      ])
                        _tableCell(Text(title, style: const TextStyle(
                          fontSize: 10, color: muted, fontWeight: FontWeight.w700)),
                          header: true),
                    ],
                  ),
                  for (final p in matches)
                    TableRow(
                      decoration: const BoxDecoration(border: Border(
                        bottom: BorderSide(color: border))),
                      children: [
                        _tableCell(Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(p.barcode, style: const TextStyle(fontSize: 10, color: muted)),
                          ],
                        )),
                        _tableCell(Text(money(p.cost), style: const TextStyle(fontSize: 11))),
                        _tableCell(Text(money(p.price), style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700))),
                        _tableCell(Text(
                          '${change(p) >= 0 ? '+' : ''}${change(p).toStringAsFixed(2)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: change(p) > 0 ? const Color(0xFF286A48)
                              : change(p) < 0 ? const Color(0xFFB34141) : muted))),
                        _tableCell(Text('${markup(p).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 11))),
                        _tableCell(Text(p.supplier, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11))),
                        _tableCell(Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            onPressed: () => edit(p),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ink,
                              side: const BorderSide(color: border),
                              visualDensity: VisualDensity.compact),
                            child: const Text('Edit', style: TextStyle(fontSize: 11)),
                          ),
                        )),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (matches.isEmpty) const Padding(padding: EdgeInsets.all(24),
          child: Center(child: Text('No products found.', style: TextStyle(fontSize: 12, color: muted)))),
      ])),
      const SizedBox(height: 12),
      const Text('Preview only: updates are in memory. Pricing is not yet published to POS terminals.', style: TextStyle(fontSize: 10, color: muted)),
    ]);
  }
}

class _ProductEdit {
  const _ProductEdit(this.price, this.cost, this.supplier);
  final double price;
  final double cost;
  final String supplier;
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({required this.product});
  final _Product product;
  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  static const ink = Color(0xFF171B1C);
  static const muted = Color(0xFF66716C);
  static const lime = Color(0xFFD9FF57);
  late final TextEditingController price;
  late final TextEditingController percent;
  late final TextEditingController cost;
  late final TextEditingController supplier;
  bool syncing = false;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    price = TextEditingController();
    percent = TextEditingController();
    cost = TextEditingController(text: widget.product.cost.toStringAsFixed(2));
    supplier = TextEditingController(text: widget.product.supplier);
    price.addListener(_priceChanged);
    percent.addListener(_percentChanged);
  }

  void _priceChanged() {
    if (syncing) return;
    final n = double.tryParse(price.text);
    if (n == null || !n.isFinite || widget.product.price <= 0) return;
    syncing = true;
    percent.text = ((n - widget.product.price) / widget.product.price * 100).toStringAsFixed(2);
    syncing = false;
    setState(() {});
  }
  void _percentChanged() {
    if (syncing) return;
    final n = double.tryParse(percent.text);
    if (n == null || !n.isFinite) return;
    syncing = true;
    price.text = (widget.product.price * (1 + n / 100)).toStringAsFixed(2);
    syncing = false;
    setState(() {});
  }

  @override
  void dispose() {
    price.dispose(); percent.dispose(); cost.dispose(); supplier.dispose();
    super.dispose();
  }

  InputDecoration field(String label, String hint) => InputDecoration(
    labelText: label, hintText: hint, isDense: true, filled: true,
    fillColor: const Color(0xFFF3F5F1),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
    labelStyle: const TextStyle(color: muted, fontSize: 12));

  @override
  Widget build(BuildContext context) {
    final base = widget.product.price;
    final proposed = double.tryParse(price.text) ?? base;
    final capital = double.tryParse(cost.text) ?? widget.product.cost;
    return Dialog(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 530), child:
        SingleChildScrollView(padding: const EdgeInsets.all(25), child: Form(key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Edit product & pricing', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19)),
            const SizedBox(height: 6),
            Text(widget.product.name, style: const TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 18),
            Container(width: double.infinity, padding: const EdgeInsets.all(13), decoration: BoxDecoration(
              color: const Color(0xFFF3F5F1), borderRadius: BorderRadius.circular(11)),
              child: Text('Current selling price   ₱${base.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: price, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: field('New selling price (₱)', base.toStringAsFixed(2)),
                validator: (s) { if ((s ?? '').trim().isEmpty) return null; final n = double.tryParse(s!); return n == null || !n.isFinite || n < 0 ? 'Enter a valid price' : null; })),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: percent, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: field('Price change (%)', '0.00'),
                validator: (s) { if ((s ?? '').trim().isEmpty) return null; final n = double.tryParse(s!); return n == null || !n.isFinite || n < -100 ? 'Invalid percentage' : null; })),
            ]),
            const SizedBox(height: 7),
            const Text('Change either field — the other updates automatically.', style: TextStyle(color: muted, fontSize: 10)),
            const SizedBox(height: 16),
            TextFormField(controller: cost, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: field('Capital / purchase cost (₱)', '0.00'),
              onChanged: (_) => setState(() {}),
              validator: (s) { final n = double.tryParse(s ?? ''); return n == null || !n.isFinite || n < 0 ? 'Enter a valid capital cost' : null; }),
            const SizedBox(height: 13),
            TextFormField(controller: supplier, decoration: field('Supplier', 'Enter supplier name'),
              validator: (s) => (s ?? '').trim().isEmpty ? 'Supplier is required' : null),
            const SizedBox(height: 15),
            Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(
              color: const Color(0xFFF2F5EC), borderRadius: BorderRadius.circular(11)),
              child: Wrap(spacing: 24, runSpacing: 8, children: [
                Text('Proposed: ₱${proposed.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text('Markup: ${capital > 0 ? ((proposed - capital) / capital * 100).toStringAsFixed(1) : '—'}%', style: const TextStyle(fontSize: 12)),
              ])),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context, _ProductEdit(double.tryParse(price.text) ?? base, double.parse(cost.text), supplier.text.trim()));
              }, style: FilledButton.styleFrom(backgroundColor: ink, foregroundColor: lime),
                child: const Text('Save changes (demo)')),
            ]),
          ])))));
  }
}
