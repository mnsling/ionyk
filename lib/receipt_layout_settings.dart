import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'ionyk_api.dart';
import 'ionyk_print_preferences.dart';

/// Local layout configuration and SAMPLE previews only.
/// These settings do not issue invoices, close fiscal days, or alter test-sales
/// and cash-count records in PostgreSQL.
class ReceiptLayoutSettings extends StatefulWidget {
  const ReceiptLayoutSettings({super.key});

  @override
  State<ReceiptLayoutSettings> createState() => _ReceiptLayoutSettingsState();
}

class _ReceiptLayoutSettingsState extends State<ReceiptLayoutSettings> {
  static const _ink = Color(0xFF171D1B);
  static const _muted = Color(0xFF69736E);
  static const _line = Color(0xFFE0E5DF);
  static const _lime = Color(0xFFD9FF57);

  final _business = TextEditingController();
  final _owner = TextEditingController();
  final _address = TextEditingController();
  final _tin = TextEditingController();
  final _min = TextEditingController();
  final _ptu = TextEditingController();
  final _machine = TextEditingController();
  final _footer = TextEditingController();
  final _cashExpected = TextEditingController();
  final _cashCounted = TextEditingController();
  int _selected = 0;
  bool _saving = false;
  bool _printing = false;
  bool _loadingPrinters = false;
  List<Printer> _printers = const [];
  String _printerName = '';


  final _names = const [
    'Sales invoice',
    'Cash denomination',
    'Current cashier report',
    'Z-reading',
  ];

  List<TextEditingController> get _controllers => [
        _business, _owner, _address, _tin, _min, _ptu,
        _machine, _footer, _cashExpected, _cashCounted,
      ];

  File get _settingsFile {
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    return File('$base${Platform.pathSeparator}IONYK Systems'
        '${Platform.pathSeparator}receipt_layout.json');
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadPrinterSelection();
  }

  // Printer preference belongs to THIS Windows machine, not PostgreSQL.
  Future<void> _loadPrinterSelection() async {
    setState(() => _loadingPrinters = true);
    try {
      final chosen = await IonykPrintPreferences.loadPrinterName();
      final printers = await Printing.listPrinters();
      if (!mounted) return;
      setState(() {
        _printers = printers;
        _printerName = chosen;
      });
    } catch (e) {
      if (mounted) _notice('Could not list Windows printers: $e');
    } finally {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  Future<void> _choosePrinter(String name) async {
    try {
      await IonykPrintPreferences.savePrinterName(name);
      if (mounted) {
        setState(() => _printerName = name);
        _notice(name.isEmpty
            ? 'Windows print dialog will be used for test printouts.'
            : 'Printer saved on this PC: $name');
      }
    } catch (e) {
      if (mounted) _notice('Printer selection could not be saved: $e');
    }
  }

  static const _storedFields = [
    'business','owner','address','tin','min','ptu','machine','footer',
  ];
  Future<void> _load() async {
    try {
      var settings=await const IonykApi().receiptSettings();
      if(settings.isEmpty && await _settingsFile.exists()) {
        // Only a fallback for existing Phase 16 locally saved fields.
        final old=jsonDecode(await _settingsFile.readAsString());
        if(old is Map) settings=Map<String,dynamic>.from(old);
      }
      if(!mounted)return;
      setState(() {
        for(var i=0;i<_storedFields.length;i++) {
          final v=settings[_storedFields[i]];
          if(v is String) _controllers[i].text=v;
        }
      });
    } catch(e) {
      if(mounted)_notice('Could not load shared receipt settings: $e');
    }
  }
  Future<void> _save() async {
    setState(()=>_saving=true);
    try {
      final fields=<String,String>{};
      for(var i=0;i<_storedFields.length;i++) {
        fields[_storedFields[i]]=_controllers[i].text.trim();
      }
      await const IonykApi().saveReceiptSettings(fields);
      if(mounted)_notice('Shared development receipt header saved in PostgreSQL.');
    } catch(e) {
      if(mounted)_notice('Unable to save shared receipt header: $e');
    } finally {if(mounted)setState(()=>_saving=false);}
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _value(TextEditingController controller, String missing) {
    final value = controller.text.trim();
    return value.isEmpty ? missing : value;
  }

  String _money(double amount) => amount.toStringAsFixed(2);
  double _number(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  String _center(String value, [int width = 38]) {
    if (value.length >= width) return value;
    final left = (width - value.length) ~/ 2;
    return '${' ' * left}$value';
  }

  String _pair(String key, String value, [int width = 38]) {
    final gap = width - key.length - value.length;
    return gap > 0 ? '$key${' ' * gap}$value' : '$key  $value';
  }

  String get _header => [
        _center(_value(_business, 'BUSINESS NAME')),
        if (_owner.text.trim().isNotEmpty)
          _center('Owner: ${_owner.text.trim()}'),
        if (_address.text.trim().isNotEmpty)
          _center(_address.text.trim()),
        if (_tin.text.trim().isNotEmpty)
          _center('VAT Reg TIN: ${_tin.text.trim()}'),
        if (_machine.text.trim().isNotEmpty)
          _center('Machine: ${_machine.text.trim()}'),
        if (_min.text.trim().isNotEmpty)
          _center('MIN: ${_min.text.trim()}'),
        if (_ptu.text.trim().isNotEmpty)
          _center('PTU: ${_ptu.text.trim()}'),
      ].join('\n');

  String get _denominations => [
        _pair('1000 x 78', '78000.00'),
        _pair('500  x 17', '8500.00'),
        _pair('200  x  0', '0.00'),
        _pair('100  x 27', '2700.00'),
        _pair('50   x  0', '0.00'),
        _pair('20   x  0', '0.00'),
        _pair('10   x 30', '300.00'),
        _pair('5    x117', '585.00'),
        _pair('1    x 12', '12.00'),
        _pair('0.25 x 24', '6.00'),
        _pair('0.10 x  0', '0.00'),
        _pair('0.05 x  0', '0.00'),
      ].join('\n');

  String get _sampleText {
    const rule = '--------------------------------------';
    const sample = '*** SAMPLE - NOT AN OFFICIAL RECORD ***';
    final expected = _number(_cashExpected);
    final counted = _number(_cashCounted);
    final difference = counted - expected;
    final varianceLabel = difference < 0 ? 'SHORT' : difference > 0 ? 'OVER' : 'BALANCED';
    final stamp = DateTime.now().toLocal().toString().split('.').first;

    switch (_selected) {
      case 0:
        return [
          _header, '', _center('SALES INVOICE - SAMPLE'), sample, rule,
          'Invoice #: SAMPLE-000001',
          'Terminal: Counter 01',
          'Cashier: Sample cashier',
          rule,
          'Qty  Description                 Price',
          rule,
          '1    Sample item A                30.00',
          '3    Sample item B @ 10.00       30.00',
          rule,
          _pair('SUBTOTAL', '60.00'),
          _pair('TOTAL', '60.00'),
          _pair('CASH', '100.00'),
          _pair('CHANGE', '40.00'),
          rule,
          _pair('VATable sales', 'N/A'),
          _pair('VAT amount', 'N/A'),
          _pair('VAT-exempt', 'N/A'),
          rule, stamp, '',
          'Customer: __________________________',
          'TIN:      __________________________',
          '', _center(_footer.text.trim()), sample,
        ].join('\n');
      case 1:
        return [
          _header, '', _center('CASH DENOMINATION'), sample, rule,
          'Terminal: Counter 03',
          'Cashier: Sample cashier',
          rule, _denominations, rule,
          _pair('TOTAL', '90103.00'),
          rule, stamp, sample,
        ].join('\n');
      case 2:
        return [
          _header, '', _center('CURRENT CASHIER REPORT'), sample, rule,
          _pair('Terminal', '03'),
          _pair('Cashier', 'Sample cashier'),
          '', _pair('GROSS SALES', '114212.55'),
          _pair('DEDUCTIONS', '0.00'),
          _pair('DAILY SALES', '114212.55'),
          rule, _pair('VATable sales', 'N/A'),
          _pair('VAT amount', 'N/A'),
          _pair('VAT-exempt sales', 'N/A'),
          _pair('NET SALES', 'N/A'),
          rule, _pair('CASH SALES', '114212.55'),
          _pair('CREDIT / DEBIT', '0.00'),
          _pair('OTHER PAYMENTS', '0.00'),
          '', _pair('TRANSACTION COUNT', '219'),
          _pair('TOTAL QTY SOLD', '3919'),
          rule, stamp, sample,
        ].join('\n');
      default:
        return [
          _header, '', _center('Z-READING FORMAT PREVIEW'),
          sample, rule,
          _pair('Terminal', '03'),
          _pair('Cashier', 'Sample cashier'),
          '', _pair('GROSS AMOUNT', '114212.55'),
          _pair('DISCOUNTS', '0.00'),
          _pair('DAILY SALES', '114212.55'),
          _pair('VATable / VAT / Exempt', 'N/A'),
          _pair('NET SALES', 'N/A'),
          rule, _pair('CASH SALES', '114212.55'),
          _pair('OTHER PAYMENTS', '0.00'),
          _pair('TRANSACTION COUNT', '219'),
          _pair('TOTAL QTY SOLD', '3919'),
          rule, _center('DENOMINATION COUNT'),
          _denominations,
          rule,
          _pair('EXPECTED CASH', _money(expected)),
          _pair('COUNTED CASH', _money(counted)),
          _pair('SHORT / OVER', _money(difference)),
          _pair('RESULT', varianceLabel),
          rule, stamp,
          _center('PREVIEW ONLY - NO FISCAL CLOSING'),
          sample,
        ].join('\n');
    }
  }

  Future<void> _printPreview() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      // Narrow paper and a monospaced font mimic the dot-matrix receipt layout.
      // Prints a WATERMARKED SAMPLE, not a real tax invoice or Z-reading.
      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(76 * PdfPageFormat.mm, 500 * PdfPageFormat.mm),
        margin: pw.EdgeInsets.all(4 * PdfPageFormat.mm),
        build: (_) => pw.Text(
          _sampleText.replaceAll('₱', 'PHP '),
          style: pw.TextStyle(font: pw.Font.courier(), fontSize: 7.3, lineSpacing: 2),
        ),
      ));
      await IonykPrintPreferences.printPdf(
        name: 'IONYK_${_names[_selected].replaceAll(' ', '_')}_SAMPLE',
        onLayout: (_) async => doc.save(),
        format: PdfPageFormat(76 * PdfPageFormat.mm, 500 * PdfPageFormat.mm),
      );
    } catch (e) {
      if (mounted) _notice('Could not print preview: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Widget _field(String label, TextEditingController c, {String? hint}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF3F4F1),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final editor = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Business header',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('Saved business fields are used on development cash reports. Verify identifiers before actual fiscal use.',
          style: TextStyle(fontSize: 10, color: _muted)),
      const SizedBox(height: 14),
      _field('Business name', _business, hint: 'Business Name'),
      const SizedBox(height: 10),
      _field('Registered proprietor', _owner, hint: 'Owner / proprietor'),
      const SizedBox(height: 10),
      _field('Business address', _address, hint: 'Business Address'),
      const SizedBox(height: 10),
      _field('Tax identification number', _tin, hint: 'Verified TIN'),
      const SizedBox(height: 10),
      _field('Machine identification number', _min, hint: 'Verified MIN'),
      const SizedBox(height: 10),
      _field('Machine / serial number', _machine, hint: 'Machine / Serial Number'),
      const SizedBox(height: 10),
      _field('Permit to Use number', _ptu, hint: 'Verified PTU'),
      const SizedBox(height: 10),
      _field('Receipt footer', _footer, hint: 'Thank you for shopping!'),
      const SizedBox(height: 14),
      const Text('Short / over formula preview',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _field('Expected cash', _cashExpected, hint: '0.00')),
        const SizedBox(width: 9),
        Expanded(child: _field('Counted cash', _cashCounted, hint: '0.00')),
      ]),
      const SizedBox(height: 8),
      const Text('Short / over = Counted cash − Expected cash. The figures here are editable sample inputs, not database totals.',
          style: TextStyle(fontSize: 10, color: _muted, height: 1.5)),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.save_outlined, size: 16),
        label: Text(_saving ? 'Saving...' : 'Save shared receipt header'),
        style: FilledButton.styleFrom(backgroundColor: _ink, foregroundColor: Colors.white),
      )),
    ]);

    final preview = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('76 mm paper preview',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        IconButton(
          tooltip: 'Copy sample text',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _sampleText));
            if (context.mounted) _notice('Sample text copied.');
          },
          icon: const Icon(Icons.copy_outlined, size: 17),
        ),
      ]),
      const SizedBox(height: 8),
      // Larger ON-SCREEN preview only. The actual PDF remains 76 mm wide.
      Center(child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
        decoration: BoxDecoration(
          color: const Color(0xFFFEFEFC),
          border: Border.all(color: _line),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 18, offset: Offset(0, 6))],
        ),
        // Center the WHOLE fixed-width column on the paper, while keeping
        // quantities and monetary amounts aligned within that column.
        child: Center(
          child: SizedBox(
            width: 292,
            child: SelectableText(
              _sampleText,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 10.3,
                height: 1.42,
                color: _ink,
              ),
            ),
          ),
        ),
      )),
      const SizedBox(height: 14),
      const Text('Printer for this computer',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      const Text('Windows printer choice is local to this PC. The business header above is shared.',
          style: TextStyle(fontSize: 10, color: _muted)),
      const SizedBox(height: 9),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          key: ValueKey('printer_$_printerName'),
          initialValue: _printers.any((p) => p.name == _printerName) ? _printerName : '',
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: '', child: Text('Show Windows print dialog')),
            for (final p in _printers)
              DropdownMenuItem(value: p.name, child: Text(p.name,
                  overflow: TextOverflow.ellipsis)),
          ],
          onChanged: _loadingPrinters ? null : (name) {
            if (name != null) _choosePrinter(name);
          },
          decoration: const InputDecoration(
            labelText: 'Receipt printer',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        )),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh Windows printer list',
          onPressed: _loadingPrinters ? null : _loadPrinterSelection,
          icon: _loadingPrinters
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
        ),
      ]),
      if (_printerName.isNotEmpty && !_printers.any((p) => p.name == _printerName))
        const Padding(padding: EdgeInsets.only(top: 7),
          child: Text('Previously selected printer is unavailable. Choose another printer.',
            style: TextStyle(fontSize: 10, color: Colors.deepOrange))),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: _printing ? null : _printPreview,
        icon: const Icon(Icons.print_outlined, size: 17),
        label: Text(_printing ? 'Opening print dialog...' : 'Print SAMPLE layout'),
      )),
      const SizedBox(height: 8),
      const Text('Business header is shared through PostgreSQL for development cash reports. These four example previews are still samples, not BIR invoices or fiscal Z-readings.',
          style: TextStyle(fontSize: 10, color: _muted, height: 1.5)),
    ]);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Receipt & report layouts',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Preview the printed formats for sales invoices, denominations, cashier reports and Z-readings.',
            style: TextStyle(fontSize: 11, color: _muted)),
        const SizedBox(height: 14),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (var i = 0; i < _names.length; i++)
            ChoiceChip(
              label: Text(_names[i], style: const TextStyle(fontSize: 11)),
              selected: _selected == i,
              selectedColor: _lime,
              onSelected: (_) => setState(() => _selected = i),
            ),
        ]),
        const SizedBox(height: 17),
        LayoutBuilder(builder: (_, constraints) {
          if (constraints.maxWidth >= 770) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 4, child: editor),
              const SizedBox(width: 24),
              Expanded(flex: 6, child: preview),
            ]);
          }
          return Column(children: [editor, const SizedBox(height: 20), preview]);
        }),
      ]),
    );
  }
}
