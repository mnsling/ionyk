import 'dart:convert';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Device-only Windows printer preference. Never store a printer name in the
/// shared PostgreSQL receipt header: each checkout PC has its own printer.
class IonykPrintPreferences {
  static File get _file {
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['USERPROFILE'] ?? Directory.current.path;
    return File('$base${Platform.pathSeparator}IONYK Systems'
        '${Platform.pathSeparator}printer_preference.json');
  }

  static Future<String> loadPrinterName() async {
    final file = _file;
    if (!await file.exists()) return '';
    final raw = jsonDecode(await file.readAsString());
    if (raw is Map && raw['printer_name'] is String) {
      return raw['printer_name'] as String;
    }
    return '';
  }

  static Future<void> savePrinterName(String printerName) async {
    final file = _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({'printer_name': printerName}));
  }

  /// Sends development PDFs through the Windows dialog by default, or directly
  /// to the previously selected Windows printer. No production fiscal printing.
  static Future<void> printPdf({
    required String name,
    required LayoutCallback onLayout,
    PdfPageFormat format = PdfPageFormat.standard,
  }) async {
    final selected = await loadPrinterName();
    if (selected.isEmpty) {
      final ok = await Printing.layoutPdf(
          name: name, onLayout: onLayout, format: format);
      if (!ok) throw StateError('Print dialog cancelled or print failed.');
      return;
    }

    final printers = await Printing.listPrinters();
    Printer? match;
    for (final p in printers) {
      if (p.name == selected) {
        match = p;
        break;
      }
    }
    if (match == null) {
      throw StateError('Selected Windows printer "$selected" was not found. '
          'Open Admin Settings and select an available printer.');
    }
    final ok = await Printing.directPrintPdf(
      printer: match,
      onLayout: onLayout,
      name: name,
      format: format,
    );
    if (!ok) throw StateError('Windows did not confirm the print request.');
  }
}
