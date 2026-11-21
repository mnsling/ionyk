import 'package:flutter/material.dart';
import 'ionyk_api.dart';

/// Admin-only credential editor. Never shows an existing password.
class AdminCredentialsPanel extends StatefulWidget {
  const AdminCredentialsPanel({super.key});
  @override
  State<AdminCredentialsPanel> createState() => _AdminCredentialsPanelState();
}

class _AdminCredentialsPanelState extends State<AdminCredentialsPanel> {
  final _username = TextEditingController(text: '000');
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  bool _saving = false;
  String? _message;

  @override
  void dispose() {
    _username.dispose();
    _current.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final user = _username.text.trim();
    if (user.isEmpty || _newPassword.text.isEmpty || _current.text.isEmpty) {
      setState(() => _message = 'Fill in all three fields.');
      return;
    }
    setState(() { _saving = true; _message = null; });
    try {
      await const IonykApi().changeAdminCredentials(
        _current.text, user, _newPassword.text,
      );
      if (!mounted) return;
      _current.clear();
      _newPassword.clear();
      setState(() { _message = 'Credentials updated. Sign out and log in again.'; });
    } catch (e) {
      if (mounted) setState(() { _message = 'Could not update credentials: $e'; });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: const Color(0xFFE0E5DF)),
      borderRadius: BorderRadius.circular(17)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
      const Text('Admin login', style: TextStyle(fontSize: 15,fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      const Text('Change your Admin username and password.',
        style: TextStyle(color: Color(0xFF6D7772),fontSize: 11)),
      const SizedBox(height: 15),
      Wrap(spacing: 10,runSpacing: 10,crossAxisAlignment: WrapCrossAlignment.end,children: [
        SizedBox(width: 190,child:TextField(controller:_username,
          decoration:const InputDecoration(labelText: 'New username'))),
        SizedBox(width: 190,child:TextField(controller:_current, obscureText:true,
          decoration:const InputDecoration(labelText: 'Current password'))),
        SizedBox(width: 190,child:TextField(controller:_newPassword, obscureText:true,
          decoration:const InputDecoration(labelText: 'New password'))),
        FilledButton(onPressed:_saving ? null : _save,
          style:FilledButton.styleFrom(backgroundColor:const Color(0xFF151B1A)),
          child:Text(_saving?'Saving...':'Save login')),
      ]),
      if (_message!=null) Padding(padding:const EdgeInsets.only(top:10),
        child:Text(_message!,style:const TextStyle(fontSize:11,color:Color(0xFF4B5A53)))),
      const SizedBox(height:8),
      const Text('Short passwords are allowed in this local test build, but are not recommended for real store use.',
        style:TextStyle(color:Color(0xFF88948E),fontSize:10)),
    ]),
  );
}
