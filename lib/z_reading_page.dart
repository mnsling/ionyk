import 'package:flutter/material.dart';
import 'ionyk_api.dart';
import 'ionyk_date_filter.dart';
import 'dev_cash_report.dart';

/// Connected DEVELOPMENT cashier report, not a fiscal Z-reading.
class ZReadingPage extends StatefulWidget {
  const ZReadingPage({super.key, this.showHeader=true});
  final bool showHeader;
  @override
  State<ZReadingPage> createState()=>_ZReadingPageState();
}
class _ZReadingPageState extends State<ZReadingPage> {
  static const muted=Color(0xFF687272);
  static const border=Color(0xFFE2E6E2);
  late Future<List<Map<String,dynamic>>> history;
  late Future<List<Map<String,dynamic>>> sessions;
  DateTimeRange? selectedRange;
  bool printing=false;
  final api=const IonykApi();
  @override
  void initState(){
    super.initState();
    history=api.testTransactions();
    sessions=api.cashSessionHistory();
  }
  void reload(){
    final newHistory=api.testTransactions();
    final newSessions=api.cashSessionHistory();
    if(!mounted)return;
    setState((){history=newHistory;sessions=newSessions;});
  }
  String money(Object? n)=>'₱${(num.tryParse('$n')??0).toStringAsFixed(2)}';
  DateTimeRange get range=>selectedRange??DateTimeRange(
    start:DateUtils.dateOnly(DateTime.now()),end:DateUtils.dateOnly(DateTime.now()));
  String day(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  bool includes(Map<String,dynamic> sale){
    final d=DateTime.tryParse('${sale['created_at']}')?.toLocal();
    if(d==null)return false;
    final current=DateUtils.dateOnly(d);
    return !current.isBefore(DateUtils.dateOnly(range.start))&&
      !current.isAfter(DateUtils.dateOnly(range.end));
  }
  Future<void> selectRange() async {
    final result=await IonykDateFilter.range(context,selected:range);
    if(!mounted||result==null)return;
    setState(()=>selectedRange=result.clear?null:result.range);
  }
  Future<void> printSession(Map<String,dynamic> session) async {
    if(printing)return;
    setState(()=>printing=true);
    try {
      final settings=await api.receiptSettings();
      await DevCashReport.printSession(session:{
        ...session,'terminal_id':IonykApi.currentTerminalId,
        'cashier':IonykApi.currentDisplayName,
      },settings:settings);
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('Unable to print test report: $e')));
    } finally {if(mounted)setState(()=>printing=false);}
  }
  Future<void> pastReports(List<Map<String,dynamic>> items) async {
    if(items.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('No session reports available yet')));
      return;
    }
    final chosen=await showDialog<Map<String,dynamic>>(context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Past test cashier sessions'),
        content:SizedBox(width:440,height:330,child:ListView.builder(
          itemCount:items.length,itemBuilder:(ctx,i){
            final item=items[i];
            return ListTile(
              title:Text('Session #${item['id']} · ${item['closed_at']==null?'Open':'Closed'}'),
              subtitle:Text('${item['opened_at']} · Expected ${money(item['expected_cash'])}'),
              onTap:()=>Navigator.pop(ctx,item));
          })),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel'))],
      ));
    if(chosen!=null&&mounted)await printSession(chosen);
  }
  Widget pair(String label,String value,{bool strong=false})=>Padding(
    padding:const EdgeInsets.symmetric(vertical:4),
    child:Row(children:[Expanded(child:Text(label,style:TextStyle(fontSize:11,
        fontWeight:strong?FontWeight.w700:FontWeight.w400))),
      Text(value,style:TextStyle(fontSize:strong?15:11,fontWeight:FontWeight.w700))]));
  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(18),
    decoration:BoxDecoration(color:Colors.white,border:Border.all(color:border),
      borderRadius:BorderRadius.circular(16)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[Expanded(child:Text(widget.showHeader?'Current cashier report':'Test closing summary',
          style:const TextStyle(fontSize:15,fontWeight:FontWeight.w700))),
        IconButton(onPressed:reload,tooltip:'Refresh',icon:const Icon(Icons.refresh,size:18))]),
      const Text('Saved development data. Not an official fiscal Z-reading.',
        style:TextStyle(fontSize:11,color:muted)),
      const SizedBox(height:12),
      FutureBuilder<List<Map<String,dynamic>>>(future:sessions,builder:(ctx,snap){
        if(!snap.hasData)return const Padding(padding:EdgeInsets.all(8),
          child:Text('Loading cashier sessions…',style:TextStyle(fontSize:11)));
        final all=snap.data!;
        final current=all.where((s)=>s['closed_at']==null).toList();
        if(current.isEmpty)return const Text('No active test cashier session.',
          style:TextStyle(fontSize:11,color:muted));
        final s=current.first;
        return Container(padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(color:const Color(0xFFF3F5F1),
            borderRadius:BorderRadius.circular(9)),
          child:Column(children:[
            pair('Session','${s['id']}'),
            pair('Cash-in-drawer / opening',money(s['opening_cash'])),
            pair('Session cash sales',money(s['cash_sales'])),
            const Divider(height:14),
            pair('Accountability / expected',money(s['expected_cash']),strong:true),
            pair('Counted',s['counted_cash']==null?'Not saved':money(s['counted_cash'])),
            pair('Short / over',s['variance']==null?'--':money(s['variance']),strong:true),
            const SizedBox(height:8),
            SizedBox(width:double.infinity,child:OutlinedButton.icon(
              onPressed:printing?null:()=>printSession(s),
              icon:const Icon(Icons.print_outlined,size:16),
              label:const Text('Print current TEST cashier report'))),
          ]));
      }),
      const SizedBox(height:14),
      OutlinedButton.icon(onPressed:selectRange,
        icon:const Icon(Icons.calendar_month_outlined,size:17),
        label:Text('${day(range.start)} – ${day(range.end)}')),
      const SizedBox(height:10),
      Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:history,
        builder:(ctx,snap){
          if(!snap.hasData)return Center(child:Text(snap.hasError
            ? 'Could not load test receipts: ${snap.error}' : 'Loading receipts…'));
          final records=snap.data!.where(includes).toList();
          final total=records.fold<double>(0,(sum,r)=>sum+
            (num.tryParse('${r['total']}')??0).toDouble());
          final qty=records.fold<int>(0,(sum,r)=>sum+
            (num.tryParse('${r['item_count']}')??0).toInt());
          return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Container(padding:const EdgeInsets.all(11),
              decoration:BoxDecoration(color:const Color(0xFFF3F5F1),
                borderRadius:BorderRadius.circular(9)),
              child:Column(children:[
                pair('Transactions in date range','${records.length}'),
                pair('Pieces sold','$qty'),
                pair('Cash sales in date range',money(total),strong:true),
              ])),
            const SizedBox(height:10),
            const Text('Saved receipts',style:TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
            Expanded(child:records.isEmpty
              ? const Center(child:Text('No test receipts for this date range',
                style:TextStyle(fontSize:11,color:muted)))
              :ListView.builder(itemCount:records.length,itemBuilder:(ctx,i){
                final r=records[i];
                return Padding(padding:const EdgeInsets.symmetric(vertical:6),
                  child:pair('Receipt #${r['receipt_no']??r['id']}',money(r['total'])));
              })),
          ]);
        })),
      const SizedBox(height:7),
      FutureBuilder<List<Map<String,dynamic>>>(future:sessions,builder:(ctx,snap){
        return OutlinedButton.icon(
          onPressed:printing?null:()=>pastReports(snap.data??[]),
          icon:const Icon(Icons.history,size:16),
          label:const Text('Past test reports · select session'));
      }),
      const SizedBox(height:7),
      const Text('Test session reports preserve count and opening float. A fiscal Z-reading, BIR tax calculations and legal end-of-day closing are not implemented.',
        style:TextStyle(fontSize:9.5,color:muted)),
    ]));
}
