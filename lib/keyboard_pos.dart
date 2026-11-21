import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ionyk_modal.dart';
import 'ionyk_api.dart';

/// Development POS: test sales are recorded in PostgreSQL; not fiscal invoices.
class KeyboardPos extends StatefulWidget {
  const KeyboardPos({super.key});
  @override
  State<KeyboardPos> createState() => _KeyboardPosState();
}

class _Product {
  final String barcode;
  final String name;
  final double price;
  const _Product(this.barcode, this.name, this.price);
}

class _Line {
  final _Product product;
  int quantity;
  _Line(this.product, this.quantity);
  double discountPercent = 0;
  String discountReason = 'No discount';
  double get total => product.price * quantity;
}

class _KeyboardPosState extends State<KeyboardPos> {
  static const ink = Color(0xFF252B34);
  static const muted = Color(0xFF616B77);
  static const border = Color(0xFFE3E7ED);
  static const canvas = Color(0xFFF5F6F8);
  static const selectedColor = Color(0xFFE9F1DE);
  final _scan = TextEditingController();
  final _scanFocus = FocusNode(debugLabel: 'Barcode');
  final _cartScrollController = ScrollController();
  final _shortcutsScrollController = ScrollController();
  final _api = const IonykApi();
  static const double _cartRowHeight = 105;
  _Product? _lastAddedProduct;
  final _lines = <_Line>[];
  int _selected = -1;
  bool _wholesale = false;
  int _manualLineCounter = 0;
  double _discountPercent = 0;
  String _discountReason = 'No discount';
  String _message = 'Ready to scan a barcode';
  bool _dialogOpen = false;
  ModalRoute<dynamic>? _posRoute;

  final _products = <_Product>[]; // Populated only from published PostgreSQL products.

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_restoreScannerFocus);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    WidgetsBinding.instance.addPostFrameCallback((_) { _focusScan(); _loadProducts(); });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _posRoute = ModalRoute.of(context);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_restoreScannerFocus);
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _scan.dispose();
    _scanFocus.dispose();
    _cartScrollController.dispose();
    _shortcutsScrollController.dispose();
    super.dispose();
  }

  String _money(double value) => '₱${value.toStringAsFixed(2)}';
  int get _units => _lines.fold(0, (sum, line) => sum + line.quantity);
  double _unitPrice(_Line line) => line.product.barcode.startsWith('MANUAL-')
      ? line.product.price : (_wholesale ? line.product.price * 0.90 : line.product.price);
  double get _subtotal => _lines.fold(0.0, (sum, line) => sum + _unitPrice(line) * line.quantity);
  double _itemDiscount(_Line line) => _unitPrice(line) * line.quantity * line.discountPercent / 100;
  double get _lineDiscountTotal => _lines.fold<double>(0, (sum, line) => sum + _itemDiscount(line));
  double get _afterItemDiscounts => _subtotal - _lineDiscountTotal;
  double get _discountValue => _afterItemDiscounts * _discountPercent / 100;
  double get _total => _afterItemDiscounts - _discountValue;

  // Global POS shortcuts work even if a mouse click temporarily changes focus.
  // While a dialog is active, key handling is left to that dialog instead.
  bool _onHardwareKey(KeyEvent event) {
    if (!mounted || _dialogOpen || event is! KeyDownEvent ||
        !(_posRoute?.isCurrent ?? false)) return false;
    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (ctrl && key == LogicalKeyboardKey.backspace) {
      _openVoidDialog();
      return true;
    }
    if (ctrl && key == LogicalKeyboardKey.arrowUp) {
      _selectRelative(-1);
      return true;
    }
    if (ctrl && key == LogicalKeyboardKey.arrowDown) {
      _selectRelative(1);
      return true;
    }
    if (key == LogicalKeyboardKey.f2) {
      _addGrocery();
      return true;
    }
    if (key == LogicalKeyboardKey.f4) {
      _replaceQuantity();
      return true;
    }
    if (key == LogicalKeyboardKey.f9) {
      _openSearchDialog();
      return true;
    }
    if (key == LogicalKeyboardKey.f12) {
      _payment();
      return true;
    }
    return false;
  }

  void _restoreScannerFocus() {
    if (_dialogOpen || !mounted || _scanFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_dialogOpen &&
          (_posRoute?.isCurrent ?? false) &&
          !_scanFocus.hasFocus) {
        _scanFocus.requestFocus();
      }
    });
  }

  Future<T?> _openPosDialog<T>(WidgetBuilder builder) async {
    if (!mounted || _dialogOpen) return null;
    _dialogOpen = true;
    // Wait for the dialog's EXIT ANIMATION and widget unmount before letting
    // callers dispose TextEditingControllers. showDialog() alone completes
    // when Navigator.pop is requested, while its widgets may still be mounted.
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<T>(
      context: context,
      barrierDismissible: true,
      builder: builder,
    );
    try {
      navigator.push<T>(route);
      return await route.completed;
    } finally {
      _dialogOpen = false;
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_dialogOpen && (_posRoute?.isCurrent ?? false)) {
            _focusScan();
          }
        });
      }
    }
  }

  void _focusScan() {
    if (!mounted || _dialogOpen) return;
    _scan.clear();
    _scanFocus.requestFocus();
  }

  void _notice(String msg) => setState(() => _message = msg);

  // Scroll the selected row into view after the list has laid out.
  // The scanner keeps keyboard focus; this only moves the cart viewport.
  void _scrollCartToRow(int row) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_cartScrollController.hasClients || row < 0) return;
      final position = _cartScrollController.position;
      final rowTop = row * _cartRowHeight;
      final rowBottom = rowTop + _cartRowHeight;
      final viewportTop = position.pixels;
      final viewportBottom = viewportTop + position.viewportDimension;
      double target = viewportTop;
      if (rowBottom > viewportBottom) {
        target = rowBottom - position.viewportDimension;
      } else if (rowTop < viewportTop) {
        target = rowTop;
      }
      target = target.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
      if ((target - position.pixels).abs() < 1) return;
      _cartScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _add(_Product product, int quantity) {
    if (quantity < 1 || quantity > 9999) { _notice('Quantity must be 1–9999'); return; }
    final found = _lines.indexWhere((line) => line.product.barcode == product.barcode);
    if (found >= 0 && _lines[found].quantity + quantity > 9999) {
      _notice('Maximum 9999 units per product'); return;
    }
    setState(() {
      if (found == -1) {
        _lines.add(_Line(product, quantity));
        _selected = _lines.length - 1;
      } else {
        _lines[found].quantity += quantity;
        _selected = found;
      }
      _lastAddedProduct = product;
      _message = 'Added $quantity × ${product.name} · F4 edits selected quantity';
    });
    _scrollCartToRow(_selected);
    _focusScan();
  }

  void _submitScan(String raw) {
    final value = raw.trim();
    if (value.isEmpty) { _focusScan(); return; }
    // Exact barcode match wins; prevents treating an ordinary barcode as a quantity.
    for (final p in _products) {
      if (p.barcode == value || p.name.toLowerCase() == value.toLowerCase()) {
        _add(p, 1);
        return;
      }
    }
    // Cashier types quantity immediately before scanning: 4 + 4800012345678.
    // This demo uses known catalog barcodes as suffixes. Production systems
    // must additionally account for variable-length barcodes and scanner timing.
    final candidates = _products.where((p) => value.endsWith(p.barcode) && value.length > p.barcode.length).toList()
      ..sort((a, b) => b.barcode.length.compareTo(a.barcode.length));
    if (candidates.isNotEmpty) {
      final p = candidates.first;
      final prefix = value.substring(0, value.length - p.barcode.length);
      final qty = int.tryParse(prefix);
      if (qty != null && qty >= 1 && qty <= 9999) {
        _add(p, qty);
        return;
      }
      _notice('Enter a quantity from 1 to 9999 before scanning');
      _focusScan();
      return;
    }
    _notice('Unknown barcode: $value');
    _focusScan();
  }

  // Pull actual published products; pending drafts must never appear in POS.
  Future<void> _loadProducts() async {
    try {
      final rows = await _api.publishedProducts();
      if (!mounted) return;
      final products = <_Product>[];
      for (final row in rows) {
        final name = (row['description'] ?? '').toString().trim();
        final barcode = (row['piece_barcode'] ?? '').toString().trim();
        final price = double.tryParse((row['piece_price'] ?? '').toString());
        if (name.isEmpty) continue;
        if (barcode.isNotEmpty && price != null && price >= 0) {
          products.add(_Product(barcode, name, price));
        }
        // Case barcode is a separate sellable unit at its own published price.
        final caseBarcode = (row['case_barcode'] ?? '').toString().trim();
        final casePrice = double.tryParse((row['case_price'] ?? '').toString());
        if (caseBarcode.isNotEmpty && casePrice != null && casePrice >= 0) {
          products.add(_Product(caseBarcode, '$name (Case)', casePrice));
        }
      }
      setState(() {
        _products..clear()..addAll(products);
        _message = products.isEmpty ? 'No published products available yet' : '${products.length} sellable product barcodes loaded';
      });
    } catch (_) {
      if (mounted) _notice('Unable to load published products. Check the local server.');
    }
  }

  Future<void> _openSearchDialog() async {
    await _loadProducts();
    if (!mounted) return;
    final search = TextEditingController();
    final selected = await _openPosDialog<_Product>((ctx) => StatefulBuilder(
      builder: (ctx, redraw) {
        final q = search.text.trim().toLowerCase();
        final matches = _products.where((p) => p.name.toLowerCase().contains(q) || p.barcode.toLowerCase().contains(q)).toList();
        return IonykModal(
          title: const Text('Search products · F9'),
          content: SizedBox(width: 680, height: 420, child: Column(children: [
            TextField(controller: search, autofocus: true, onChanged: (_) => redraw(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name or barcode')),
            const SizedBox(height: 14),
            Container(color: const Color(0xFFF0F3EF), padding: const EdgeInsets.all(12), child: const Row(children: [
              Expanded(flex: 5, child: Text('PRODUCT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(flex: 3, child: Text('BARCODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
            ])),
            Expanded(child: matches.isEmpty
              ? const Center(child: Text('No published products found'))
              : ListView.separated(itemCount: matches.length, separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final p = matches[i];
                    return InkWell(onTap: () => Navigator.of(ctx).pop(p), child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                      child: Row(children: [
                        Expanded(flex: 5, child: Text(p.name, overflow: TextOverflow.ellipsis)),
                        Expanded(flex: 3, child: Text(p.barcode, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                        Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text(_money(p.price)))),
                      ]),
                    ));
                  })),
          ])),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
        );
      },
    ));
    search.dispose();
    if (!mounted) return;
    if (selected != null) _add(selected, 1);
  }

  void _selectRow(int i) {
    if (_lines.isEmpty) { _notice('Scan an item first'); return; }
    setState(() {
      _selected = i.clamp(0, _lines.length - 1).toInt();
      _message = 'Selected ${_lines[_selected].product.name} · F4 to edit quantity';
    });
    _scrollCartToRow(_selected);
    _scanFocus.requestFocus();
  }

  void _selectRelative(int delta) {
    if (_lines.isEmpty) { _notice('Scan an item first'); return; }
    _selectRow((_selected < 0 ? 0 : _selected + delta).clamp(0, _lines.length - 1).toInt());
  }

  // Manual item: a single price and a fixed "Grocery" description.
  // Each entry is a separate line so differing prices are never merged.
  Future<void> _addGrocery() async {
    final amount = TextEditingController();
    final price = await _openPosDialog<double>((ctx) => IonykModal(
      title: const Text('Add grocery'),
      content: SizedBox(width: 330, child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No barcode · Description: Grocery',
              style: TextStyle(color: Color(0xFF67736D), fontSize: 12)),
          const SizedBox(height: 14),
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(
              labelText: 'Amount (₱)',
              hintText: '0.00',
              helperText: 'Quantity defaults to 1. Use F4 to change it.',
            ),
            onSubmitted: (_) {
              final entered = double.tryParse(amount.text.trim());
              if (entered != null && entered.isFinite && entered > 0) {
                Navigator.pop(ctx, entered);
              }
            },
          ),
        ],
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final entered = double.tryParse(amount.text.trim());
          if (entered != null && entered.isFinite && entered > 0) {
            Navigator.pop(ctx, entered);
          }
        }, child: const Text('Add to cart')),
      ],
    ));
    amount.dispose();
    if (!mounted) return;
    if (price != null) {
      _manualLineCounter += 1;
      _add(_Product('MANUAL-$_manualLineCounter', 'Grocery', price), 1);
    }
    _focusScan();
  }

  Future<void> _replaceQuantity() async {
    if (_selected < 0 || _selected >= _lines.length) { _notice('Select a cart item first'); _focusScan(); return; }
    final line = _lines[_selected];
    final controller = TextEditingController();
    final result = await _openPosDialog<int>((ctx) => IonykModal(
      title: const Text('Edit quantity'),
      content: SizedBox(width: 330, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF5F7F2), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('SELECTED PRODUCT', style: TextStyle(fontSize: 10, color: Color(0xFF657169), fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(line.product.name, style: const TextStyle(color: Color(0xFF151A1A), fontSize: 14, fontWeight: FontWeight.w600))])), const SizedBox(height: 17),
        TextField(autofocus: true, controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'New quantity',
            hintText: '${line.quantity}',
            helperText: 'Current: ${line.quantity} · Enter the new quantity',
          ),
          onSubmitted: (_) {
            final parsed = int.tryParse(controller.text.trim());
            if (parsed != null && parsed >= 1 && parsed <= 9999) {
              Navigator.pop(ctx, parsed);
            }
          }),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final parsed = int.tryParse(controller.text.trim());
          if (parsed != null && parsed >= 1 && parsed <= 9999) {
            Navigator.pop(ctx, parsed);
          }
        }, child: const Text('Update quantity'))],
    ));
    controller.dispose();
    if (!mounted) return;
    if (result != null && result >= 1 && result <= 9999) {
      setState(() { line.quantity = result; _lastAddedProduct = line.product; _message = 'Quantity set to $result for ${line.product.name}'; });
    }
    _focusScan();
  }

  Future<void> _openVoidDialog() async {
    if (_lines.isEmpty) {
      _notice('No scanned items to void');
      return;
    }
    final chosen = <_Line>{};
    final adminUser = TextEditingController();
    final adminPass = TextEditingController();
    bool submitting = false;
    bool obscure = true;
    String? error;
    final approved = await _openPosDialog<bool>((ctx) => StatefulBuilder(
      builder: (ctx, redraw) => IonykModal(
        title: const Text('Void scanned products'),
        content: SizedBox(width: 575, height: 460, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Select the products to remove from this transaction.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          Container(color: const Color(0xFFF0F3EF), padding: const EdgeInsets.all(9), child: const Row(children: [
            SizedBox(width: 45), Expanded(child: Text('PRODUCT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            Text('QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ])),
          Expanded(child: ListView.builder(itemCount: _lines.length, itemBuilder: (ctx, index) {
            final line = _lines[index];
            return CheckboxListTile(
              dense: true, controlAffinity: ListTileControlAffinity.leading,
              value: chosen.contains(line),
              onChanged: (value) => redraw(() { if (value == true) { chosen.add(line); } else { chosen.remove(line); } }),
              title: Text(line.product.name, style: const TextStyle(fontSize: 12)),
              subtitle: Text(line.product.barcode, style: const TextStyle(fontSize: 10)),
              secondary: Text('${line.quantity} × ${_money(_unitPrice(line))}', style: const TextStyle(fontSize: 11)),
            );
          })),
          const Divider(),
          Text('Selected: ${chosen.length} of ${_lines.length} products', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: adminUser, decoration: const InputDecoration(labelText: 'Admin username'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: adminPass, obscureText: obscure,
              decoration: InputDecoration(labelText: 'Admin password', suffixIcon: IconButton(
                onPressed: () => redraw(() => obscure = !obscure),
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))))),
          ]),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(error!, style: const TextStyle(fontSize: 11, color: Colors.red))),
        ])),
        actions: [
          TextButton(onPressed: submitting ? null : () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: submitting ? null : () async {
            if (chosen.isEmpty || adminUser.text.trim().isEmpty || adminPass.text.isEmpty) {
              redraw(() => error = 'Select at least one product and enter Admin credentials.');
              return;
            }
            redraw(() { submitting = true; error = null; });
            try {
              final allowed = await _api.authorizeVoid(adminUser.text, adminPass.text);
              if (!ctx.mounted) return;
              if (allowed) { Navigator.of(ctx).pop(true); return; }
              redraw(() => error = 'Admin approval denied.');
            } catch (_) {
              if (ctx.mounted) redraw(() => error = 'Approval denied or server unavailable.');
            } finally {
              if (ctx.mounted) redraw(() => submitting = false);
            }
          }, child: Text(submitting ? 'Verifying...' : 'Void selected')),
        ],
      ),
    ));
    adminUser.dispose();
    adminPass.dispose();
    if (!mounted || approved != true) return;
    setState(() {
      _lines.removeWhere(chosen.contains);
      if (_lastAddedProduct != null && !_lines.any((line) => line.product.barcode == _lastAddedProduct!.barcode)) {
        _lastAddedProduct = null;
      }
      _selected = _lines.isEmpty ? -1 : 0;
      _message = 'Voided ${chosen.length} selected products with Admin approval (local cart only).';
    });
  }

  Future<void> _setDiscount() async {
    bool forSelected = _selected >= 0 && _selected < _lines.length;
    final selectedLine = forSelected ? _lines[_selected] : null;
    // Keep the current discount as a hint so typing replaces it immediately.
    final percent = TextEditingController();
    String reason = 'Promotional (demo)';
    final result = await _openPosDialog<(bool, double, String)>(
      (ctx) => StatefulBuilder(builder: (ctx, setModal) => IonykModal(
        title: const Text('Apply discount'),
        content: SizedBox(width: 385, child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose whether the discount applies to a product or the entire cart.',
              style: TextStyle(fontSize: 12, color: Color(0xFF67736D))),
            const SizedBox(height: 18),
            SegmentedButton<bool>(showSelectedIcon: false, selected: {forSelected},
              segments: const [
                ButtonSegment(value: true, label: Text('Selected product')),
                ButtonSegment(value: false, label: Text('Entire sale')),
              ],
              onSelectionChanged: (choice) {
                final nextScope = choice.first;
                if (nextScope == forSelected) return;
                setModal(() => forSelected = nextScope);
                // Clear any draft when the scope changes. The active scope's
                // previously applied percentage is shown as a placeholder.
                percent.clear();
              },
            ),
            const SizedBox(height: 12),
            if (forSelected) Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF1F5EC), borderRadius: BorderRadius.circular(9)),
              child: Text(selectedLine?.product.name ?? 'Select a cart product first',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 15),
            TextField(controller: percent, autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: 'Discount (%)',
                hintText: (forSelected
                    ? (selectedLine?.discountPercent ?? 0)
                    : _discountPercent).toStringAsFixed(0),
                helperText: 'Type a percentage to apply (0–100)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(initialValue: reason,
              items: const ['Promotional (demo)', 'Loyalty offer (demo)', 'Manager adjustment (demo)']
                .map((x) => DropdownMenuItem(value: x, child: Text(x, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) { if (value != null) setModal(() => reason = value); },
              decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text('Demo promotional pricing only. Senior Citizen/PWD tax treatment requires a separate verified workflow.',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF67736D))),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final value = double.tryParse(percent.text);
            if (value != null && value.isFinite && value >= 0 && value <= 100 && (!forSelected || selectedLine != null)) {
              Navigator.pop(ctx, (forSelected, value, reason));
            }
          }, child: const Text('Apply discount')),
        ],
      )),
    );
    percent.dispose();
    if (!mounted) return;
    if (result != null) {
      setState(() {
        if (result.$1 && selectedLine != null) {
          selectedLine.discountPercent = result.$2;
          selectedLine.discountReason = result.$3;
        } else {
          _discountPercent = result.$2;
          _discountReason = result.$3;
        }
      });
    }
    _focusScan();
  }

  Future<void> _payment() async {
    if (_lines.isEmpty) { _notice('Scan a product first'); return; }
    final amount=_total;
    final controller=TextEditingController();
    final tendered=await _openPosDialog<double>((ctx)=>StatefulBuilder(
      builder:(ctx,refreshDialog)=>IonykModal(
      title:const Row(children:[Icon(Icons.payments_outlined,size:21),SizedBox(width:10),Text('Cash payment')]),
      content:SizedBox(width:410,child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(
          color:const Color(0xFF151A1A),borderRadius:BorderRadius.circular(14)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('AMOUNT DUE',style:TextStyle(fontSize:10,color:Color(0xFFBCC7BD),letterSpacing:1.2)),
            const SizedBox(height:6),
            Text(_money(amount),style:const TextStyle(fontSize:30,fontWeight:FontWeight.w700,color:Color(0xFFD9FF57))),
          ])),
        const SizedBox(height:18),
        TextField(controller:controller,autofocus:true,
          keyboardType:const TextInputType.numberWithOptions(decimal:true),
          inputFormatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration:const InputDecoration(labelText:'Cash received',prefixText:'₱ ',
            hintText:'Enter cash tendered'),
          onChanged:(_)=>refreshDialog((){}),
          onSubmitted:(_){ final n=double.tryParse(controller.text);if(n!=null&&n>=amount)Navigator.pop(ctx,n); }),
        const SizedBox(height:13),
        Builder(builder:(_){
          final entered=double.tryParse(controller.text)??0;
          final enough=entered>=amount;
          return Container(padding:const EdgeInsets.symmetric(vertical:13,horizontal:15),
            decoration:BoxDecoration(color:const Color(0xFFF2F5EE),borderRadius:BorderRadius.circular(11)),
            child:Row(children:[const Expanded(child:Text('Change',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600))),
              Text(_money(enough?entered-amount:0),style:const TextStyle(fontSize:21,fontWeight:FontWeight.w700))]));
        }),
        const SizedBox(height:14),
        const Text('DEVELOPMENT TEST ONLY · Not an official receipt or BIR invoice',
          style:TextStyle(fontSize:10,color:Color(0xFF687272))),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:(double.tryParse(controller.text)??0)<amount?null:
          ()=>Navigator.pop(ctx,double.tryParse(controller.text)),
          child:const Text('Complete test payment'))],
    )));
    controller.dispose();
    if (!mounted || tendered==null) return;
    if (!tendered.isFinite || tendered<amount) { _notice('Cash received is insufficient'); return; }
    try {
      final saved=await _api.recordTestSale({
        'tendered':tendered,'wholesale':_wholesale,
        'sale_discount_percent':_discountPercent,
        'items':_lines.map((line){
          final manual = line.product.barcode.startsWith('MANUAL-');
          return {
            'barcode':manual ? null : line.product.barcode,
            'manual':manual,
            if (manual) 'description':'Grocery',
            if (manual) 'unit_price':line.product.price,
            'quantity':line.quantity,
            'discount_percent':line.discountPercent,
          };
        }).toList(),
      });
      if (!mounted) return;
      setState(() { _lines.clear();_selected=-1;_lastAddedProduct=null;_discountPercent=0; });
      await _openPosDialog<void>((ctx)=>IonykModal(
        title:const Text('Payment saved'),
        content:SizedBox(width:350,child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Icon(Icons.check_circle_outline,size:44,color:Color(0xFF6D9B2B)),
          const SizedBox(height:10),
          Text('Test receipt #${saved['receipt_no'] ?? saved['id']}',textAlign:TextAlign.center,
            style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700)),
          const SizedBox(height:14),
          Text('Total: ${_money(amount)}'),
          Text('Cash: ${_money(tendered)}'),
          Text('Change: ${_money(tendered-amount)}',style:const TextStyle(fontWeight:FontWeight.w700)),
          const SizedBox(height:12),
          const Text('Open Transactions to view the saved receipt.',
            style:TextStyle(color:Color(0xFF687272),fontSize:11)),
        ])),
        actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Done'))],
      ));
    } catch(e) { if(mounted) _notice('Unable to save test sale: $e'); }
    _focusScan();
  }

  Future<void> _paymentPreviewOnly() async {
    if (_lines.isEmpty) { _notice('Add products before payment'); _focusScan(); return; }
    final amount = _total;
    // Leave the field empty for immediate typing; amount due is only a hint.
    final controller = TextEditingController();
    final tendered = await _openPosDialog<double>((ctx) => IonykModal(
      title: const Text('Cash payment'),
      content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF151A1A), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('AMOUNT DUE', style: TextStyle(color: Color(0xFFBBC4BD), fontSize: 10, fontWeight: FontWeight.w700)), const SizedBox(height: 7), Text(_money(amount), style: const TextStyle(color: Color(0xFFD9FF57), fontWeight: FontWeight.w700, fontSize: 29))])),
        const SizedBox(height: 16),
        TextField(autofocus: true, controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(labelText: 'Cash received', prefixText: '₱ ', hintText: amount.toStringAsFixed(2)),
          onSubmitted: (_) => Navigator.pop(ctx, double.tryParse(controller.text))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)), child: const Text('Calculate change'))],
    ));
    controller.dispose();
    if (!mounted) return;
    if (tendered != null) {
      if (!tendered.isFinite || tendered < amount) {
        _notice('Cash received is less than the amount due');
      } else {
        await _openPosDialog<void>((ctx) => IonykModal(
          title: const Text('Change calculation'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Amount due       ${_money(amount)}'), const SizedBox(height: 9), Text('Cash received    ${_money(tendered)}'), const Divider(height: 30), Text('CHANGE  ${_money(tendered - amount)}', style: const TextStyle(color: Color(0xFF151A1A), fontSize: 21, fontWeight: FontWeight.bold)), const SizedBox(height: 18), const Text('UI preview only. No sale or invoice has been saved.', style: TextStyle(fontSize: 11))]),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Return to cart'))],
        ));
      }
    }
    _focusScan();
  }

  // IONYK Atelier checkout. Demo behavior is unchanged; all content is in-memory.
  static const _ink = Color(0xFF151A1A);
  static const _secondary = Color(0xFF67736D);
  static const _line = Color(0xFFE2E7E2);
  static const _accent = Color(0xFF94C52B);
  static const _cream = Color(0xFFF2F8E8);
  static const _navy = Color(0xFF151A1A);

  Widget _panel({required Widget child, Color color = Colors.white, EdgeInsetsGeometry? padding}) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(22),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color == Colors.white ? _line : Colors.transparent)),
    child: child,
  );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _modeSelector(),
    const SizedBox(height: 16),
    LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 830;
      // Fixed shared row height keeps both columns aligned and avoids
      // intrinsic sizing of the scrollable cart (which Flutter disallows).
      if (wide) return SizedBox(height: 740, child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Column(children: [
            _scanPanel(),
            const SizedBox(height: 15),
            Expanded(child: _transactionPanel(fillHeight: true)),
          ])),
          const SizedBox(width: 16),
          SizedBox(width: 285, child: Column(children: [
            _summaryPanel(),
            const SizedBox(height: 15),
            Expanded(child: _shortcutsPanel()),
          ])),
        ],
      ));
      return Column(children: [_scanPanel(), const SizedBox(height: 15), _transactionPanel(), const SizedBox(height: 15), _summaryPanel(), const SizedBox(height: 15), SizedBox(height: 250, child: _shortcutsPanel())]);
    }),
  ]);

  Widget _modeSelector() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      const Text('PRICING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .7, color: _secondary)),
      const SizedBox(width: 18),
      SegmentedButton<bool>(
        style: ButtonStyle(visualDensity: VisualDensity.compact, textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        segments: const [ButtonSegment(value: false, label: Text('Retail')), ButtonSegment(value: true, label: Text('Wholesale'))],
        selected: {_wholesale}, showSelectedIcon: false,
        onSelectionChanged: (value) => setState(() => _wholesale = value.first),
      ),
      const SizedBox(width: 16),
      Expanded(child: Text(_wholesale ? 'Demo wholesale tier · 10% below retail' : 'Standard retail pricing', style: const TextStyle(color: _secondary, fontSize: 11))),
      OutlinedButton(onPressed: _setDiscount, child: Text(_discountPercent > 0 ? 'Sale discount ${_discountPercent.toStringAsFixed(0)}%' : 'Discounts · Item / Sale', style: const TextStyle(fontSize: 11))),
    ]),
  );

  Widget _scanPanel() => _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Scan product', style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
      Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEDFABD), borderRadius: BorderRadius.circular(20)),
        child: const Text('READY', style: TextStyle(color: Color(0xFF315B15), fontWeight: FontWeight.w700, fontSize: 9, letterSpacing: .6))),
    ]),
    const SizedBox(height: 14),
    TextField(controller: _scan, focusNode: _scanFocus, onSubmitted: _submitScan,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink),
      cursorColor: _accent,
      decoration: InputDecoration(
        hintText: 'Scan barcode  ·  or type quantity then scan',
        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF7B8681), fontWeight: FontWeight.w400),
        filled: true, fillColor: const Color(0xFFF2F5ED),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFCFD8CB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _accent, width: 1.7)),
      ),
    ),
    const SizedBox(height: 9),
    Text(_message, style: const TextStyle(color: _secondary, fontSize: 11)),
    const SizedBox(height: 12),
    Align(alignment: Alignment.centerLeft, child: TextButton.icon(
      onPressed: _openSearchDialog,
      icon: const Icon(Icons.search, size: 16),
      label: const Text('Search published products   F9'),
    )),
  ]));

  Widget _transactionPanel({bool fillHeight = false}) => _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Expanded(child: Text('Current transaction', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _ink))),
      Text('${_lines.length} products  ·  $_units units', style: const TextStyle(color: _secondary, fontSize: 11)),
    ]),
    const SizedBox(height: 17),
    Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF0F3EF), borderRadius: BorderRadius.circular(9)),
      child: const Row(children: [
        Expanded(flex: 5, child: Text('PRODUCT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _secondary))),
        Expanded(flex: 2, child: Text('PRICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _secondary))),
        Expanded(flex: 1, child: Text('QTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _secondary))),
        Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _secondary)))),
      ]),
    ),
    const SizedBox(height: 8),
    (fillHeight ? Expanded(child: _cartContents()) : SizedBox(height: 316, child: _cartContents())),
    const SizedBox(height: 10),
    const Text('Ctrl + ↑ / ↓ to select  ·  F4 to edit quantity', style: TextStyle(fontSize: 10.5, color: _secondary)),
  ]));

  Widget _cartContents() => _lines.isEmpty
      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inventory_2_outlined, color: Color(0xFFB9C5BE), size: 28),
          const SizedBox(height: 12),
          const Text('No items in this transaction', style: TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Scan a barcode to get started', style: TextStyle(color: _secondary, fontSize: 11)),
        ]))
      : ListView.builder(
          controller: _cartScrollController,
          primary: false,
          itemExtent: _cartRowHeight,
          itemCount: _lines.length,
          itemBuilder: (context, i) {
          final line = _lines[i]; final active = i == _selected;
          return InkWell(onTap: () => _selectRow(i), borderRadius: BorderRadius.circular(10),
            child: Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(color: active ? const Color(0xFFF0F9DA) : const Color(0xFFFAFBF9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: active ? const Color(0xFF9CCD39) : _line, width: active ? 1.3 : 1)),
              child: Row(children: [
                Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(line.product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(line.product.barcode.startsWith('MANUAL-') ? 'No barcode' : line.product.barcode,
                    style: const TextStyle(color: _secondary, fontSize: 10)),
                  if (line.discountPercent > 0) Text('Discount ${line.discountPercent.toStringAsFixed(1)}% · −${_money(_itemDiscount(line))}',
                    style: const TextStyle(color: Color(0xFF446B17), fontSize: 10, fontWeight: FontWeight.w600)),
                ])),
                Expanded(flex: 2, child: Text(_money(_unitPrice(line)), style: const TextStyle(color: _ink, fontSize: 11.5))),
                Expanded(flex: 1, child: Text('${line.quantity}', style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700))),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight,
                  child: Text(_money(_unitPrice(line) * line.quantity - _itemDiscount(line)), style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700)))),
              ]),
            ),
          );
        });

  // Show the live cart quantity and discounted line total for the most
  // recently added or quantity-edited item.
  Widget _lastAddedPreview() {
    final product = _lastAddedProduct;
    final lineIndex = product == null ? -1 :
        _lines.indexWhere((line) => line.product.barcode == product.barcode);
    if (product == null || lineIndex == -1) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF232A27),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF3B4740)),
        ),
        child: const Text('Last added item will appear here',
          style: TextStyle(color: Color(0xFFBBC8C1), fontSize: 11)),
      );
    }
    final line = _lines[lineIndex];
    final unitPrice = _unitPrice(line);
    final lineTotal = unitPrice * line.quantity - _itemDiscount(line);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF242C27),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF425244)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('LAST ADDED', style: TextStyle(
          color: Color(0xFFD9FF57), fontSize: 9, fontWeight: FontWeight.w700,
          letterSpacing: .65,
        )),
        const SizedBox(height: 7),
        Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13.5,
            fontWeight: FontWeight.w600, height: 1.2)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('${line.quantity} × ${_money(unitPrice)}',
            style: const TextStyle(color: Color(0xFFCBD6CE), fontSize: 11.5))),
          Text(_money(lineTotal),
            style: const TextStyle(color: Colors.white, fontSize: 15,
              fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _summaryPanel() => _panel(color: _navy, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('PAYMENT SUMMARY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFBBC8C1), letterSpacing: .8)),
    const SizedBox(height: 20),
    Text(_wholesale ? 'Wholesale · Amount due' : 'Retail · Amount due', style: const TextStyle(fontSize: 12, color: Color(0xFFD8E0DB))),
    const SizedBox(height: 4),
    Text(_money(_total), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -1.1)),
    const SizedBox(height: 16),
    _lastAddedPreview(),
    const SizedBox(height: 16),
    const Divider(color: Color(0xFF3A4540), height: 1),
    const SizedBox(height: 13),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Before discount', style: TextStyle(color: Color(0xFFD0DBD3), fontSize: 11)),
      Text(_money(_subtotal), style: const TextStyle(color: Colors.white, fontSize: 11)),
    ]),
    const SizedBox(height: 8),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Product discounts', style: TextStyle(color: Color(0xFFD0DBD3), fontSize: 11)),
      Text('-${_money(_lineDiscountTotal)}', style: const TextStyle(color: Color(0xFFD9FF57), fontSize: 11)),
    ]),
    const SizedBox(height: 8),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Sale discount (${_discountPercent.toStringAsFixed(0)}%)', style: const TextStyle(color: Color(0xFFD0DBD3), fontSize: 11)),
      Text('-${_money(_discountValue)}', style: const TextStyle(color: Color(0xFFD9FF57), fontSize: 11)),
    ]),
    const SizedBox(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Total units', style: TextStyle(fontSize: 11.5, color: Color(0xFFD0DBD3))),
      Text('$_units', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12.5)),
    ]),
    const SizedBox(height: 20),
    SizedBox(width: double.infinity, child: FilledButton(
      onPressed: _payment,
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD9FF57), foregroundColor: _ink,
        padding: const EdgeInsets.symmetric(vertical: 17), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
      child: const Text('Continue to payment     F12', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    )),
    const SizedBox(height: 12),
    const Text('TEST SALES ONLY · not BIR invoices', style: TextStyle(fontSize: 10, color: Color(0xFFBBC8C1))),
  ]));

  Widget _shortcutsPanel() => _panel(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Keyboard shortcuts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
      const SizedBox(height: 12),
      Expanded(child: Scrollbar(controller: _shortcutsScrollController, thumbVisibility: true,
        child: ListView(controller: _shortcutsScrollController, primary: false, padding: const EdgeInsets.only(right: 12), children: [
          _shortcut('F2', 'Add Grocery (no barcode)'),
          _shortcut('F4', 'Edit selected quantity'),
          _shortcut('F9', 'Search published products'),
          _shortcut('Ctrl + ↑ / ↓', 'Select for quantity / discount'),
          _shortcut('4 + scan', 'Add four pieces'),
          _shortcut('Ctrl + Backspace', 'Void items'),
          _shortcut('F12', 'Payment / save test transaction'),
        ]),
      )),
    ],
  ));

  Widget _shortcut(String key, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFEFF3E9), borderRadius: BorderRadius.circular(6), border: Border.all(color: _line)),
        child: Text(key, style: const TextStyle(fontSize: 10, color: _ink, fontWeight: FontWeight.w600))),
      const SizedBox(width: 10),
      Expanded(child: Text(desc, style: const TextStyle(fontSize: 11, color: _secondary))),
    ]),
  );
}
