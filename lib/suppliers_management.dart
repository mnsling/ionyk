import 'package:flutter/material.dart';
import 'ionyk_api.dart';
import 'ionyk_admin_table.dart';

class IonykSuppliersPanel extends StatefulWidget {
  const IonykSuppliersPanel({super.key});
  @override State<IonykSuppliersPanel> createState()=>_IonykSuppliersPanelState();
}
class _IonykSuppliersPanelState extends State<IonykSuppliersPanel> {
  final api=const IonykApi();
  late Future<List<Map<String,dynamic>>> suppliers;
  @override void initState(){super.initState();suppliers=api.suppliers();}
  void refresh(){setState(() { suppliers=api.suppliers(); });}
  Future<void> add() async {
    final name=TextEditingController(),phone=TextEditingController();
    bool saving=false;
    try {
      await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
        title:const Text('Add supplier'),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:name,decoration:const InputDecoration(labelText:'Supplier name')),
          const SizedBox(height:10),TextField(controller:phone,decoration:const InputDecoration(labelText:'Contact number (optional)')),
        ])),actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(ctx),child:const Text('Cancel')),
          FilledButton(onPressed:saving?null:() async {
            if(name.text.trim().isEmpty)return;
            update(()=>saving=true);
            try{await api.addSupplier(name.text,phone.text);
              if(!ctx.mounted || !mounted)return;
              Navigator.of(ctx).pop();refresh();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Supplier saved to PostgreSQL.')));
            }catch(e){
              if(!ctx.mounted)return;
              update(()=>saving=false);
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('Supplier not saved: $e')));
            }
          },child:Text(saving?'Saving...':'Save supplier'))],
      )));
    }finally{name.dispose();phone.dispose();}
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:suppliers,builder:(context,snapshot){
    final data=snapshot.data??[];
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Suppliers',style:TextStyle(fontWeight:FontWeight.w700,fontSize:24)),
        Text('Saved supplier directory · orders and deliveries not yet tracked',style:TextStyle(fontSize:11,color:Colors.grey)),
      ])),TextButton.icon(onPressed:refresh,icon:const Icon(Icons.refresh),label:const Text('Refresh')),
        const SizedBox(width:8),FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:const Text('Add supplier'))]),
      const SizedBox(height:18),Row(children:[Expanded(child:Container(padding:const EdgeInsets.all(20),
        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Registered suppliers',style:TextStyle(fontSize:12,color:Colors.grey)),
          const SizedBox(height:10),Text('${data.length}',style:const TextStyle(fontSize:27,fontWeight:FontWeight.w700))]))),
        const SizedBox(width:12),Expanded(child:Container(padding:const EdgeInsets.all(20),
        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),
        child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Purchase orders',style:TextStyle(fontSize:12,color:Colors.grey)),SizedBox(height:10),
          Text('--',style:TextStyle(fontSize:27,fontWeight:FontWeight.w700))])))]),
      const SizedBox(height:16),Container(padding:const EdgeInsets.all(18),
        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('Supplier directory',style:TextStyle(fontSize:15,fontWeight:FontWeight.w700)),
          const SizedBox(height:10),
          if(snapshot.hasError)Text('Could not load suppliers: ${snapshot.error}',style:const TextStyle(color:Colors.red)),
          if(!snapshot.hasData && !snapshot.hasError)const Center(child:CircularProgressIndicator()),
          IonykAdminTable(
            columns: const ['Supplier', 'Contact', 'Products'],
            emptyMessage: 'No suppliers added yet',
            rows: [for (final item in data) [
              '${item['name']}', '${item['phone'] ?? '--'}', '${item['product_count']}',
            ]],
          ),
        ])),
    ]);
  });
}
