import 'package:flutter/material.dart';
import 'ionyk_api.dart';

/// Admin counter setup: one row per counter, one editable cashier login per row.
class CounterManagementPanel extends StatefulWidget {
  const CounterManagementPanel({super.key});

  @override
  State<CounterManagementPanel> createState() => _CounterManagementPanelState();
}

class _CounterManagementPanelState extends State<CounterManagementPanel> {
  final IonykApi api = const IonykApi();
  List<Map<String, dynamic>> counters = [];
  bool busy = false;
  String? notification;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    loadCounters();
  }

  Future<void> loadCounters() async {
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final results = await api.terminals();
      if (mounted) setState(() => counters = results);
    } catch (e) {
      showStatus('Cannot load counters: $e', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void showStatus(String value, {bool error = false}) {
    if (!mounted) return;
    setState(() { notification = value; isError = error; });
  }

  Future<void> addCounter() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final created = await api.createCounter('');
      await loadCounters();
      if (!mounted) return;
      showStatus('Counter added. Set its name and login using Edit.');
      final item = counters.where((c) => c['id'] == created['id']).toList();
      if (item.isNotEmpty) await editCounter(item.first);
    } catch (e) {
      showStatus('Cannot add counter: $e', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editCounter(Map<String, dynamic> counter) async {
    final name = TextEditingController(text:
      (counter['cashier_display_name'] ?? counter['display_name'] ?? '').toString());
    final username = TextEditingController(text:
      (counter['cashier_username'] ?? '').toString());
    final password = TextEditingController();
    final hasAccount = counter['cashier_user_id'] != null;
    bool submitting = false;
    bool revealPassword = false;
    String? errorText;
    final edited = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(builder: (context, repaint) {
        InputDecoration field(String label) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF3F4F1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        );
        return AlertDialog(
          title: Text('Edit ${counter['label']}'),
          content: SizedBox(width: 380, child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: name, decoration: field('Display name')),
              const SizedBox(height: 12),
              TextField(controller: username, decoration: field('Username (e.g. 001)')),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: !revealPassword,
                decoration: field(hasAccount ? 'New password (leave blank to keep)' : 'Password').copyWith(
                  suffixIcon: IconButton(
                    onPressed: () => repaint(() => revealPassword = !revealPassword),
                    icon: Icon(revealPassword ? Icons.visibility_off : Icons.visibility),
                    tooltip: revealPassword ? 'Hide password' : 'Show password',
                  ),
                ),
              ),
              if (errorText != null) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ],
          )),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
            FilledButton(
              onPressed: submitting ? null : () async {
                if (name.text.trim().isEmpty || username.text.trim().isEmpty ||
                    (!hasAccount && password.text.isEmpty)) {
                  repaint(() => errorText = 'Enter a display name, username and password.');
                  return;
                }
                repaint(() { submitting = true; errorText = null; });
                try {
                  await api.updateCounterLogin(counter['id'] as int,
                    name.text.trim(), username.text.trim(), password.text);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  repaint(() { errorText = '$e'; submitting = false; });
                }
              },
              child: Text(submitting ? 'Saving...' : 'Save changes'),
            ),
          ],
        );
      }),
    );
    // Controllers are no longer used after the dialog closes.
    name.dispose();
    username.dispose();
    password.dispose();
    if (edited == true) {
      await loadCounters();
      showStatus('Counter details saved to PostgreSQL.');
    }
  }

  Future<void> removeCounter(Map<String, dynamic> counter) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${counter['label']}?'),
        content: const Text('This counter will be disabled and hidden from active counters. Its cashier cannot log in. Historical records will be preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await api.deactivateCounter(counter['id'] as int);
      await loadCounters();
      showStatus('Counter removed.');
    } catch (e) {
      showStatus('Could not remove counter: $e', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF151B1A);
    const muted = Color(0xFF6A746E);
    const border = Color(0xFFE1E6E0);
    final active = counters.where((c) => c['is_active'] == true).toList();
    final removed = counters.where((c) => c['is_active'] != true).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Counters', style: TextStyle(color: dark, fontSize: 17, fontWeight: FontWeight.w700)),
            SizedBox(height: 5),
            Text('Add a counter, then set its cashier login with Edit.',
              style: TextStyle(color: muted, fontSize: 12)),
          ])),
          FilledButton.icon(onPressed: busy ? null : addCounter,
            icon: const Icon(Icons.add, size: 17), label: const Text('Add counter')),
        ]),
        const SizedBox(height: 20),
        if (active.isEmpty)
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 34),
            alignment: Alignment.center,
            child: const Text('No counters yet. Click Add counter to create Counter 01.',
              style: TextStyle(color: muted, fontSize: 13))),
        for (final counter in active)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: const Color(0xFFF7F8F6),
              borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              SizedBox(width: 125, child: Text('${counter['label']}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(counter['cashier_user_id'] == null ? 'Not configured'
                    : '${counter['cashier_display_name'] ?? counter['display_name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 3),
                Text(counter['cashier_user_id'] == null ? 'No login set'
                    : 'Username: ${counter['cashier_username']}',
                  style: const TextStyle(color: muted, fontSize: 11)),
              ])),
              TextButton.icon(onPressed: busy ? null : () => editCounter(counter),
                icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
              TextButton(onPressed: busy ? null : () => removeCounter(counter),
                child: const Text('Remove')),
            ]),
          ),
        if (removed.isNotEmpty)
          ExpansionTile(title: Text('Removed counters (${removed.length})',
            style: const TextStyle(color: muted, fontSize: 12)),
            tilePadding: EdgeInsets.zero,
            children: [for (final counter in removed)
              ListTile(
                dense: true,
                title: Text('${counter['label']}'),
                trailing: TextButton(
                  onPressed: busy ? null : () async {
                    try {
                      await api.restoreCounter(counter['id'] as int);
                      await loadCounters();
                    } catch (e) {
                      showStatus('Cannot restore: $e', error: true);
                    }
                  },
                  child: const Text('Restore'),
                ),
              ),
            ],
          ),
        if (notification != null)
          Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(notification!, style: TextStyle(fontSize: 12,
              color: isError ? Colors.red : const Color(0xFF417D35)))),
        if (busy) const Padding(padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator()),
      ]),
    );
  }
}
