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
      this.supplier, this.stock, {this.previousPrice, double? wholesalePrice, this.unitsPerCase = 1})
      : wholesalePrice = wholesalePrice ?? price;
  final String barcode;
  final String name;
  final String category;
  double cost;
  double price;
  double wholesalePrice;
  int unitsPerCase;
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
      product.wholesalePrice = result.wholesalePrice;
      product.unitsPerCase = result.unitsPerCase;
    });
    message('Preview updated for ${product.name}. No real POS price was changed.');
  }

  Future<void> addProduct() async {
    final result = await showDialog<_ProductDetails>(
      context: context,
      builder: (_) => const _ProductDetailsDialog(),
    );
    if (!mounted || result == null) return;
    final barcode = result.barcode.trim();
    if (products.any((p) => p.barcode == barcode)) {
      message('This barcode is already registered. Edit the existing product instead.');
      return;
    }
    setState(() {
      products.add(_Product(
        barcode, result.name, result.category, result.cost,
        result.retailPrice, result.supplier, 0,
        wholesalePrice: result.wholesalePrice,
        unitsPerCase: result.unitsPerCase,
      ));
      query = '';
      search.clear();
    });
    message('Product added to demo catalogue. Not saved to database yet.');
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
        OutlinedButton.icon(onPressed: importPreview,
          icon: const Icon(Icons.upload_file_outlined, size: 17),
          label: const Text('Import Excel'),
          style: OutlinedButton.styleFrom(foregroundColor: ink,
            side: const BorderSide(color: border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)))),
        const SizedBox(width: 10),
        FilledButton.icon(onPressed: addProduct,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Product'),
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
              width: constraints.maxWidth < 1140 ? 1140 : constraints.maxWidth,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(3.0),
                  1: FlexColumnWidth(1.1),
                  2: FlexColumnWidth(1.3),
                  3: FlexColumnWidth(1.3),
                  4: FlexColumnWidth(1.25),
                  5: FlexColumnWidth(1.1),
                  6: FlexColumnWidth(.9),
                  7: FlexColumnWidth(1.5),
                  8: FlexColumnWidth(.85),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: soft),
                    children: [
                      for (final title in [
                        'PRODUCT / BARCODE', 'CAPITAL', 'RETAIL PRICE',
                        'WHOLESALE PRICE', 'PRICE CHANGE', 'MARKUP',
                        'PCS / CASE', 'SUPPLIER', 'ACTION'
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
                        _tableCell(Text(money(p.wholesalePrice), style: const TextStyle(fontSize: 11))),
                        _tableCell(Text(
                          '${change(p) >= 0 ? '+' : ''}${change(p).toStringAsFixed(2)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: change(p) > 0 ? const Color(0xFF286A48)
                              : change(p) < 0 ? const Color(0xFFB34141) : muted))),
                        _tableCell(Text('${markup(p).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 11))),
                        _tableCell(Text('${p.unitsPerCase}', style: const TextStyle(fontSize: 11))),
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
  const _ProductEdit(this.price, this.cost, this.supplier,
      this.wholesalePrice, this.unitsPerCase);
  final double price;
  final double cost;
  final String supplier;
  final double wholesalePrice;
  final int unitsPerCase;
}

class _ProductDetails {
  const _ProductDetails({required this.barcode, required this.name,
      required this.category, required this.cost, required this.retailPrice,
      required this.wholesalePrice, required this.unitsPerCase, required this.supplier});
  final String barcode, name, category, supplier;
  final double cost, retailPrice, wholesalePrice;
  final int unitsPerCase;
}

// Shared input styling between Add Product and Edit Product.
class _ProductDialogStyle {
  static const ink = Color(0xFF171B1C);
  static const muted = Color(0xFF66716C);
  static const lime = Color(0xFFD9FF57);
  static InputDecoration field(String label, String hint) => InputDecoration(
    labelText: label, hintText: hint, isDense: true, filled: true,
    fillColor: const Color(0xFFF3F5F1),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
    labelStyle: const TextStyle(color: muted, fontSize: 12));
  static ButtonStyle primary() => FilledButton.styleFrom(
    backgroundColor: ink, foregroundColor: lime,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)));
}

class _ProductDetailsDialog extends StatefulWidget {
  const _ProductDetailsDialog();
  @override
  State<_ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<_ProductDetailsDialog> {
  final key = GlobalKey<FormState>();
  final barcode = TextEditingController();
  final name = TextEditingController();
  final category = TextEditingController();
  final cost = TextEditingController();
  final retail = TextEditingController();
  final retailMarkup = TextEditingController();
  final wholesale = TextEditingController();
  final pieces = TextEditingController(text: '1');
  final supplier = TextEditingController();
  final barcodeFocus = FocusNode();
  bool _syncingMarkup = false;

  @override
  void initState() {
    super.initState();
    retail.addListener(_retailChanged);
    retailMarkup.addListener(_markupChanged);
    cost.addListener(_costChanged);
  }
  void _retailChanged() {
    if (_syncingMarkup) return;
    _syncingMarkup = true;
    final c = double.tryParse(cost.text);
    final r = double.tryParse(retail.text);
    retailMarkup.text = c != null && c > 0 && r != null
        ? ((r - c) / c * 100).toStringAsFixed(2) : '';
    _syncingMarkup = false;
    if (mounted) setState(() {});
  }
  void _markupChanged() {
    if (_syncingMarkup) return;
    _syncingMarkup = true;
    final c = double.tryParse(cost.text);
    final pct = double.tryParse(retailMarkup.text);
    retail.text = c != null && pct != null && pct >= -100
        ? (c * (1 + pct / 100)).toStringAsFixed(2) : '';
    _syncingMarkup = false;
    if (mounted) setState(() {});
  }
  void _costChanged() {
    if (retailMarkup.text.isNotEmpty) {
      _markupChanged();
    } else {
      _retailChanged();
    }
    if (mounted) setState(() {});
  }
  @override
  void dispose() {
    barcode.dispose(); name.dispose(); category.dispose(); cost.dispose();
    retail.dispose(); retailMarkup.dispose(); wholesale.dispose(); pieces.dispose(); supplier.dispose();
    barcodeFocus.dispose(); super.dispose();
  }
  String? requiredText(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;
  String? nonNegative(String? v) {
    final n = double.tryParse((v ?? '').trim());
    return n == null || !n.isFinite || n < 0 ? 'Enter a valid amount' : null;
  }
  Widget gap() => const SizedBox(height: 13);

  @override
  Widget build(BuildContext context) {
    final c = double.tryParse(cost.text) ?? 0;
    final r = double.tryParse(retail.text) ?? 0;
    final margin = r > 0 ? (r - c) / r * 100 : 0.0;
    final markup = c > 0 ? (r - c) / c * 100 : 0.0;
    return Dialog(backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 590, maxHeight: 760),
        child: SingleChildScrollView(padding: const EdgeInsets.all(24),
          child: Form(key: key, child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add product', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              const Text('Scan the barcode, then enter the product details.',
                style: TextStyle(fontSize: 12, color: _ProductDialogStyle.muted)),
              const SizedBox(height: 18),
              TextFormField(controller: barcode, focusNode: barcodeFocus,
                autofocus: true, keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                decoration: _ProductDialogStyle.field('Barcode', 'Scan barcode here'),
                validator: requiredText),
              gap(),
              TextFormField(controller: name,
                decoration: _ProductDialogStyle.field('Product description', 'e.g. Coca-Cola 1.5L'),
                validator: requiredText),
              gap(),
              TextFormField(controller: category,
                decoration: _ProductDialogStyle.field('Category', 'Beverages, grocery, etc.'),
                validator: requiredText),
              gap(),
              Row(children: [
                Expanded(child: TextFormField(controller: cost,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _ProductDialogStyle.field('Capital per piece (₱)', '0.00'),
                  validator: nonNegative)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: pieces,
                  keyboardType: TextInputType.number,
                  decoration: _ProductDialogStyle.field('Pieces in one case', '1'),
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter at least 1' : null)),
              ]),
              gap(),
              Row(children: [
                Expanded(child: TextFormField(controller: retail,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _ProductDialogStyle.field('Retail price per piece (₱)', '0.00'),
                  validator: nonNegative)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: wholesale,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _ProductDialogStyle.field('Wholesale price per piece (₱)', '0.00'),
                  validator: nonNegative)),
              ]),
              gap(),
              TextFormField(controller: retailMarkup,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: _ProductDialogStyle.field('Retail markup (%)', 'Calculated from capital and retail price'),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return null;
                  final n = double.tryParse(v!);
                  return n == null || !n.isFinite || n < -100 ? 'Invalid markup percentage' : null;
                }),
              const SizedBox(height: 6),
              const Text('Changing markup recalculates retail price, and vice versa.',
                style: TextStyle(fontSize: 10, color: _ProductDialogStyle.muted)),
              gap(),
              TextFormField(controller: supplier,
                decoration: _ProductDialogStyle.field('Supplier (optional)', 'e.g. Suysing')),
              const SizedBox(height: 15),
              Container(width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF2F5EC),
                  borderRadius: BorderRadius.circular(11)),
                child: Wrap(spacing: 22, runSpacing: 8, children: [
                  Text('Retail markup: ${markup.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('Gross margin: ${margin.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12)),
                  Text('Profit / piece: ₱${(r-c).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12)),
                ])),
              const SizedBox(height: 19),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(style: _ProductDialogStyle.primary(),
                  onPressed: () {
                    if (!key.currentState!.validate()) return;
                    Navigator.pop(context, _ProductDetails(
                      barcode: barcode.text.trim(), name: name.text.trim(),
                      category: category.text.trim(),
                      cost: double.parse(cost.text.trim()),
                      retailPrice: double.parse(retail.text.trim()),
                      wholesalePrice: double.parse(wholesale.text.trim()),
                      unitsPerCase: int.parse(pieces.text.trim()),
                      supplier: supplier.text.trim(),
                    ));
                  }, child: const Text('Add product (demo)')),
              ]),
            ],
          )),
        ),
      ),
    );
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({required this.product});
  final _Product product;
  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController price;
  late final TextEditingController percent;
  late final TextEditingController wholesale;
  late final TextEditingController cost;
  late final TextEditingController supplier;
  late final TextEditingController pieces;
  bool syncing = false;

  @override
  void initState() {
    super.initState();
    price = TextEditingController(); // Blank: original price is a placeholder.
    percent = TextEditingController();
    cost = TextEditingController(text: widget.product.cost.toStringAsFixed(2));
    wholesale = TextEditingController();
    supplier = TextEditingController(text: widget.product.supplier);
    pieces = TextEditingController(text: widget.product.unitsPerCase.toString());
    price.addListener(_priceChanged);
    percent.addListener(_percentChanged);
    cost.addListener(() { if (mounted) setState(() {}); });
  }
  void _priceChanged() {
    if (syncing) return;
    syncing = true;
    final n = double.tryParse(price.text);
    if (n == null || !n.isFinite || widget.product.price <= 0) {
      percent.clear();
    } else {
      percent.text = ((n-widget.product.price)/widget.product.price*100).toStringAsFixed(2);
    }
    syncing = false;
    if (mounted) setState(() {});
  }
  void _percentChanged() {
    if (syncing) return;
    syncing = true;
    final n = double.tryParse(percent.text);
    if (n == null || !n.isFinite) {
      price.clear();
    } else {
      price.text = (widget.product.price*(1+n/100)).toStringAsFixed(2);
    }
    syncing = false;
    if (mounted) setState(() {});
  }
  @override
  void dispose() {
    price.dispose(); percent.dispose(); cost.dispose(); supplier.dispose();
    wholesale.dispose(); pieces.dispose(); super.dispose();
  }
  String? amount(String? s) {
    if ((s ?? '').trim().isEmpty) return null;
    final n = double.tryParse(s!);
    return n == null || !n.isFinite || n < 0 ? 'Enter a valid amount' : null;
  }
  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final proposed = double.tryParse(price.text) ?? p.price;
    final capital = double.tryParse(cost.text) ?? p.cost;
    return Dialog(backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 570, maxHeight: 710),
        child: SingleChildScrollView(padding: const EdgeInsets.all(24),
          child: Form(key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Edit product & pricing',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19)),
                const SizedBox(height: 5),
                Text('${p.name}  ·  ${p.barcode}',
                  style: const TextStyle(color: _ProductDialogStyle.muted, fontSize: 12)),
                const SizedBox(height: 17),
                Container(width: double.infinity, padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: const Color(0xFFF3F5F1),
                    borderRadius: BorderRadius.circular(11)),
                  child: Text('Current retail price  ₱${p.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: price, autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _ProductDialogStyle.field('New retail price (₱)',p.price.toStringAsFixed(2)),
                    validator: amount)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: percent,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: _ProductDialogStyle.field('Retail price change (%)','0.00'),
                    validator: (s) {
                      if ((s ?? '').trim().isEmpty) return null;
                      final n = double.tryParse(s!);
                      return n == null || !n.isFinite || n < -100 ? 'Invalid percentage' : null;
                    })),
                ]),
                const SizedBox(height: 7),
                const Text('Edit either field; the other updates automatically.',
                  style: TextStyle(color: _ProductDialogStyle.muted, fontSize: 10)),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _ProductDialogStyle.field('Capital per piece (₱)',p.cost.toStringAsFixed(2)),
                    validator: (s) => amount(s) ?? ((s ?? '').isEmpty ? 'Required' : null))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: wholesale,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _ProductDialogStyle.field('Wholesale per piece (₱)',p.wholesalePrice.toStringAsFixed(2)),
                    validator: amount)),
                ]),
                const SizedBox(height: 13),
                Row(children: [
                  Expanded(child: TextFormField(controller: pieces,
                    keyboardType: TextInputType.number,
                    decoration: _ProductDialogStyle.field('Pieces in one case',p.unitsPerCase.toString()),
                    validator: (s) => (int.tryParse(s ?? '') ?? 0) < 1 ? 'At least 1' : null)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: supplier,
                    decoration: _ProductDialogStyle.field('Supplier (optional)', 'Supplier name'))),
                ]),
                const SizedBox(height: 15),
                Container(width: double.infinity, padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF2F5EC),
                    borderRadius: BorderRadius.circular(11)),
                  child: Wrap(spacing: 20, runSpacing: 8, children: [
                    Text('Proposed retail: ₱${proposed.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    Text('Markup: ${capital > 0 ? ((proposed-capital)/capital*100).toStringAsFixed(1) : '—'}%',
                      style: const TextStyle(fontSize: 12)),
                  ])),
                const SizedBox(height: 19),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(style: _ProductDialogStyle.primary(),
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(context, _ProductEdit(
                        double.tryParse(price.text) ?? p.price,
                        double.parse(cost.text), supplier.text.trim(),
                        double.tryParse(wholesale.text) ?? p.wholesalePrice,
                        int.parse(pieces.text),
                      ));
                    }, child: const Text('Save changes (demo)')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
