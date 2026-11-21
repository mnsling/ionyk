import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'ionyk_print_preferences.dart';

/// Only DEVELOPMENT REPORTS. Not an invoice, fiscal X/Z report, or BIR receipt.
class DevCashReport {
  static double numValue(Object? x) => (num.tryParse('$x') ?? 0).toDouble();
  static String money(Object? x) => numValue(x).toStringAsFixed(2);
  static String safe(Object? x, [String other = '--']) {
    final value=(x ?? '').toString().trim();
    return value.isEmpty ? other : value;
  }
  static pw.Widget row(String name,String value,{bool bold=false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical:2.8),
    child:pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[
      pw.Expanded(child:pw.Text(name,style:pw.TextStyle(fontSize:8,
        fontWeight:bold?pw.FontWeight.bold:pw.FontWeight.normal))),
      pw.Text(value,style:pw.TextStyle(fontSize:8,
        fontWeight:bold?pw.FontWeight.bold:pw.FontWeight.normal)),
    ]));
  static List<pw.Widget> header(Map<String,dynamic> settings) => [
    pw.Center(child:pw.Text(safe(settings['business'],'IONYK SYSTEMS'),
      style:pw.TextStyle(fontWeight:pw.FontWeight.bold,fontSize:12))),
    for(final pair in <(String,String)>[
      ('Owner',safe(settings['owner'],'')),
      ('Address',safe(settings['address'],'')),
      ('TIN',safe(settings['tin'],'')),
      ('Machine',safe(settings['machine'],'')),
      ('MIN',safe(settings['min'],'')),
      ('PTU',safe(settings['ptu'],'')),
    ]) if(pair.$2.isNotEmpty) pw.Center(child:pw.Text('${pair.$1}: ${pair.$2}',
      textAlign:pw.TextAlign.center,style:const pw.TextStyle(fontSize:7))),
    pw.SizedBox(height:8),
  ];
  static Future<void> _print(String title,List<pw.Widget> contents) async {
    final doc=pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat:PdfPageFormat(76*PdfPageFormat.mm,370*PdfPageFormat.mm),
      margin:pw.EdgeInsets.all(5*PdfPageFormat.mm),
      build:(_)=>contents));
    await IonykPrintPreferences.printPdf(
      onLayout:(_)=>doc.save(), name:title,
      format:PdfPageFormat(76*PdfPageFormat.mm,370*PdfPageFormat.mm),
    );
  }

  static Future<void> printSale({required Map<String,dynamic> receipt,
      required Map<String,dynamic> settings}) async {
    final rawLines=(receipt['lines'] as List?)??const [];
    await _print('IONYK_TEST_Receipt_${receipt['receipt_no']??receipt['id']}',[
      ...header(settings),
      pw.Center(child:pw.Text('DEVELOPMENT TEST RECEIPT',
        style:pw.TextStyle(fontWeight:pw.FontWeight.bold,fontSize:10))),
      pw.Center(child:pw.Text('NOT AN OFFICIAL BIR INVOICE',
        style:const pw.TextStyle(fontSize:7))),
      pw.Divider(),
      row('Receipt #',safe(receipt['receipt_no'],safe(receipt['id']))),
      row('Counter',safe(receipt['terminal_id'])),
      row('Cashier',safe(receipt['cashier'])),
      row('Recorded',safe(receipt['created_at'])),
      pw.Divider(),
      for(final entry in rawLines) ...[
        pw.Text(safe((entry as Map)['description'],'Grocery'),
          style:const pw.TextStyle(fontSize:8)),
        row('${entry['quantity']} x ${money(entry['unit_price'])}',
          money(entry['line_total'])),
      ],
      pw.Divider(),
      row('TOTAL','PHP ${money(receipt['total'])}',bold:true),
      row('CASH RECEIVED','PHP ${money(receipt['tendered'])}'),
      row('CHANGE','PHP ${money(receipt['change_due'])}'),
      pw.Divider(),
      pw.Text(safe(settings['footer'],''),style:const pw.TextStyle(fontSize:7)),
      pw.Text('TEST ONLY. No BIR VAT computation, certified invoice numbering or PTU authorization.',
        style:const pw.TextStyle(fontSize:7)),
    ]);
  }

  static Future<void> printDenominations({required Map<double,int> counts,
      required Map<String,dynamic> settings,Map<String,dynamic>? session}) async {
    final total=counts.entries.fold<double>(0,(v,e)=>v+e.key*e.value);
    await _print('IONYK_TEST_Denominations',[
      ...header(settings),
      pw.Center(child:pw.Text('TEST CASH DENOMINATION',
        style:pw.TextStyle(fontSize:10,fontWeight:pw.FontWeight.bold))),
      pw.Center(child:pw.Text('NOT AN OFFICIAL REPORT',
        style:const pw.TextStyle(fontSize:7))),
      pw.Divider(),
      row('Counter','${safe(session?['terminal_id'],safe(session?['id']))}'),
      row('Cashier',safe(session?['cashier'],'')),
      for(final e in counts.entries) row('${money(e.key)} x ${e.value}',money(e.key*e.value)),
      pw.Divider(),row('COUNTED CASH','PHP ${money(total)}',bold:true),
      row('Printed',DateTime.now().toLocal().toString().split('.').first),
      pw.Text('Development count preview only. Not a fiscal closing record.',
        style:const pw.TextStyle(fontSize:7)),
    ]);
  }

  static Future<void> printSession({required Map<String,dynamic> session,
      required Map<String,dynamic> settings}) async {
    final closed=session['closed_at']!=null;
    final opening=numValue(session['opening_cash']);
    final sales=numValue(session['cash_sales']??session['session_cash_sales']);
    final expected=opening+sales;
    final counted=session['counted_cash'];
    final variance=counted==null?null:numValue(counted)-expected;
    Map<String,dynamic> denominations={};
    if(session['denominations'] is Map) {
      denominations=Map<String,dynamic>.from(session['denominations'] as Map);
    }
    await _print('IONYK_TEST_Cashier_Session_${session['id']}',[
      ...header(settings),
      pw.Center(child:pw.Text(closed?'TEST END-SESSION REPORT':'CURRENT CASHIER TEST REPORT',
        style:pw.TextStyle(fontSize:10,fontWeight:pw.FontWeight.bold))),
      pw.Center(child:pw.Text('NOT A BIR X/Z READING OR OFFICIAL INVOICE',
        style:const pw.TextStyle(fontSize:7))),
      pw.Divider(),
      row('Counter',safe(session['counter'],'${session['terminal_id']??'--'}')),
      row('Cashier',safe(session['cashier'],'')),
      row('Session ID',safe(session['id'])),
      row('Opened',safe(session['opened_at'])),
      row('Closed',safe(session['closed_at'],'Still open')),
      pw.Divider(),
      row('Transactions',safe(session['transaction_count'],'0')),
      row('Quantity sold',safe(session['items_sold'],'0')),
      row('Development cash sales','PHP ${money(sales)}'),
      row('Other tenders / refunds','N/A'),
      pw.Divider(),
      row('CASH-IN-DRAWER (OPENING)','PHP ${money(opening)}'),
      row('CASH SALES','PHP ${money(sales)}'),
      row('CASH-IN / PICKUPS / PAID-OUT','N/A'),
      row('ACCOUNTABILITY / EXPECTED','PHP ${money(expected)}',bold:true),
      pw.Divider(),
      if(denominations.isNotEmpty) ...[
        pw.Text('DENOMINATION COUNTS',
          style:pw.TextStyle(fontSize:8,fontWeight:pw.FontWeight.bold)),
        for(final e in denominations.entries)
          row('${e.key} x ${e.value}',money(numValue(e.key)*numValue(e.value))),
        pw.Divider(),
      ],
      row('COUNTED CASH',counted==null?'NOT SAVED':'PHP ${money(counted)}'),
      row('SHORT / OVER',variance==null?'N/A':'PHP ${money(variance)}',bold:true),
      pw.Divider(),
      row('Report printed',DateTime.now().toLocal().toString().split('.').first),
      pw.SizedBox(height:8),
      pw.Text('Development-only printout. Does not allocate VAT, issue a tax invoice, increment a Z counter, or perform a legal fiscal close.',
        style:const pw.TextStyle(fontSize:7)),
    ]);
  }
}
