import 'package:flutter/material.dart';

class ZReadingHistoryDialog extends StatelessWidget {
  const ZReadingHistoryDialog({super.key});
  @override
  Widget build(BuildContext context)=>AlertDialog(
    title:const Text('Past Z-Readings'),
    content:const SizedBox(width:420,height:200,child:Center(child:Text('No saved Z-Readings yet.',
      style:TextStyle(color:Color(0xFF69716E))))),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))],
  );
}
