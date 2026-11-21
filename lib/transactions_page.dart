import 'package:flutter/material.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Text('Transactions',style:TextStyle(fontSize:25,fontWeight:FontWeight.w600)),
    const SizedBox(height:6),
    const Text('Sales and receipts will appear after real checkout is connected.',style:TextStyle(fontSize:12,color:Color(0xFF69716E))),
    const SizedBox(height:18),
    Expanded(child:Container(
      decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xFFE1E6E0)),
        borderRadius:BorderRadius.circular(16)),
      child:const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Icon(Icons.receipt_long_outlined,size:36,color:Color(0xFF69716E)),
        SizedBox(height:12),Text('No transactions yet',style:TextStyle(fontSize:14,fontWeight:FontWeight.w600)),
        SizedBox(height:5),Text('There are no saved receipts or transaction histories.',style:TextStyle(fontSize:12,color:Color(0xFF69716E))),
      ])),
    )),
  ]);
}
