import 'package:flutter/material.dart';
import 'z_reading_history.dart';

class ZReadingPage extends StatelessWidget {
  const ZReadingPage({super.key,this.showHeader=true});
  final bool showHeader;
  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(20),
    decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xFFE1E6E0)),
      borderRadius:BorderRadius.circular(16)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      if (showHeader) const Text('Z-Reading',style:TextStyle(fontSize:16,fontWeight:FontWeight.w600)),
      if (showHeader) const SizedBox(height:16),
      Expanded(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.summarize_outlined,size:34,color:Color(0xFF69716E)),
        const SizedBox(height:12),
        const Text('No Z-Reading available',style:TextStyle(fontSize:14,fontWeight:FontWeight.w600)),
        const SizedBox(height:5),
        const Text('Fiscal readings require recorded transactions and a verified closing process.',
          textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:Color(0xFF69716E))),
      ]))),
      OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(ctx)=>const ZReadingHistoryDialog()),
        icon:const Icon(Icons.history),label:const Text('Past reports')),
    ]));
}
