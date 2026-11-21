import 'package:flutter/material.dart';
import 'ionyk_api.dart';
import 'ionyk_admin_table.dart';

// Development inventory: persisted received stock, not official stock ledger.
// Test checkouts currently do NOT deduct from these quantities.
class IonykInventoryPanel extends StatefulWidget {
  const IonykInventoryPanel({super.key});
  @override
  State<IonykInventoryPanel> createState() => _IonykInventoryPanelState();
}
class _IonykInventoryPanelState extends State<IonykInventoryPanel> {
  final api=const IonykApi();
  late Future<List<Map<String,dynamic>>> data;
  @override void initState(){super.initState();data=api.inventory();}
  void reload(){setState(() { data=api.inventory(); });}
  String money(Object? v)=>'₱${(num.tryParse('$v')??0).toStringAsFixed(2)}';
  Widget tile(String label,String value,IconData icon)=>Expanded(child:Container(
    padding:const EdgeInsets.all(18),
    decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xFFE0E5DF)),borderRadius:BorderRadius.circular(16)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text(label,style:const TextStyle(color:Color(0xFF6D7772),fontSize:12))),Icon(icon,size:18)]),
      const SizedBox(height:12),Text(value,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w700)),
    ])));
  Future<void> receive(List<Map<String,dynamic>> products) async {
    if(products.isEmpty) return;
    int selected=(products.first['product_id'] as num).toInt();
    final pieces=TextEditingController(text:'0'),cases=TextEditingController(text:'0'),reorder=TextEditingController();
    bool saving=false;
    try {
      await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,update)=>AlertDialog(
        title:const Text('Receive stock'),
        content:SizedBox(width:440,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('Saved to development inventory in pieces. Case quantities are converted automatically.',style:TextStyle(fontSize:12)),
          const SizedBox(height:15),DropdownButtonFormField<int>(
            initialValue:selected,decoration:const InputDecoration(labelText:'Published product'),
            items:[for(final p in products) DropdownMenuItem(value:(p['product_id'] as num).toInt(),child:Text('${p['description']}'))],
            onChanged:(v){if(v!=null) update(()=>selected=v);}),
          const SizedBox(height:10),TextField(controller:pieces,keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'Loose pieces received')),
          const SizedBox(height:10),TextField(controller:cases,keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'Cases received')),
          const SizedBox(height:10),TextField(controller:reorder,keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'Reorder alert at (pieces, optional)')),
        ])),
        actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),
          FilledButton(onPressed:saving?null:() async {
            final p=int.tryParse(pieces.text),c=int.tryParse(cases.text);
            final r=reorder.text.trim().isEmpty?null:int.tryParse(reorder.text);
            if(p==null || c==null || p<0 || c<0 || p+c==0 ||
               (reorder.text.trim().isNotEmpty && r==null)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter valid whole numbers and a positive receipt quantity.')));return;
            }
            update(()=>saving=true);
            try {await api.receiveStock(selected,p,c,reorderLevel:r);
              if(!dialogContext.mounted || !mounted)return;
              Navigator.of(dialogContext).pop();
              reload();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Stock received and saved to PostgreSQL.')));
            } catch(e){
              if(!dialogContext.mounted)return;
              update(()=>saving=false);
              ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content:Text('Could not receive stock: $e')));
            }
          },child:Text(saving?'Saving...':'Save stock'))],
      )));
    } finally {pieces.dispose();cases.dispose();reorder.dispose();}
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:data,builder:(context,snapshot){
    final items=snapshot.data??[];
    final stock=items.fold<int>(0,(sum,p)=>sum+((p['quantity_pieces'] as num?)?.toInt()??0));
    final value=items.fold<double>(0,(sum,p)=>sum+(num.tryParse('${p['cost_per_piece']}')??0)*((p['quantity_pieces'] as num?)?.toInt()??0));
    final low=items.where((p){
      final threshold=(p['reorder_level'] as num?)?.toInt()??0;
      final available=(p['quantity_pieces'] as num?)?.toInt()??0;
      return threshold>0 && available<=threshold;
    }).length;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Inventory',style:TextStyle(fontWeight:FontWeight.w700,fontSize:24)),
        Text('Development receiving ledger · test sales do not deduct stock',style:TextStyle(fontSize:11,color:Colors.grey)),
      ])),TextButton.icon(onPressed:reload,icon:const Icon(Icons.refresh),label:const Text('Refresh')),
        const SizedBox(width:8),FilledButton.icon(onPressed:items.isEmpty?null:()=>receive(items),icon:const Icon(Icons.add_box_outlined),label:const Text('Receive stock'))]),
      const SizedBox(height:18),Row(children:[tile('Published products','${items.length}',Icons.inventory_2_outlined),
        const SizedBox(width:12),tile('Available pieces','$stock',Icons.warehouse_outlined),
        const SizedBox(width:12),tile('Low stock','$low',Icons.warning_amber_outlined),
        const SizedBox(width:12),tile('Stock value',money(value),Icons.account_balance_wallet_outlined)]),
      const SizedBox(height:16),Container(
        padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(17),border:Border.all(color:const Color(0xFFE0E5DF))),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('Stock overview',style:TextStyle(fontWeight:FontWeight.w700,fontSize:15)),const SizedBox(height:10),
          if(snapshot.hasError) Text('Could not load inventory: ${snapshot.error}',style:const TextStyle(color:Colors.red)),
          if(!snapshot.hasData && !snapshot.hasError)const Center(child:CircularProgressIndicator()),
          IonykAdminTable(
            columns: const ['Product', 'Pieces', 'Pcs / Case', 'Reorder Level', 'Est. Cost Value'],
            emptyMessage: 'No published products available',
            rows: [for (final p in items) [
              '${p['description']}', '${p['quantity_pieces']}', '${p['pieces_per_case']}',
              '${p['reorder_level']}',
              money((num.tryParse('${p['cost_per_piece']}') ?? 0) *
                ((p['quantity_pieces'] as num?)?.toInt() ?? 0)),
            ]],
          ),
        ])),
    ]);
  });
}
