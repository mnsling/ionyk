import 'package:flutter/material.dart';

/// Shared cashier dialog style. Keep this a *single* AlertDialog: wrapping it
/// in an extra inherited Theme during route disposal can complicate the
/// inherited-widget dependency lifecycle on some Flutter versions.
class IonykModal extends StatelessWidget {
  const IonykModal({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(25, 23, 25, 0),
      contentPadding: const EdgeInsets.fromLTRB(25, 18, 25, 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 9, 20, 20),
      actionsAlignment: MainAxisAlignment.end,
      title: Row(children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFD9FF57),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF151A1A),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            child: title,
          ),
        ),
      ]),
      content: content,
      actions: actions,
    );
  }
}
