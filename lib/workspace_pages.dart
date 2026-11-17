import 'package:flutter/material.dart';

// IONYK Systems v0.4 — visual-only workspaces with fictional preview data.
class WorkspacePages extends StatelessWidget {
  const WorkspacePages({super.key, required this.title, required this.admin});
  final String title;
  final bool admin;

  static const ink = Color(0xFF171B1C);
  static const muted = Color(0xFF687272);
  static const lime = Color(0xFFD9FF57);
  static const lavender = Color(0xFFE8F1DC);
  static const blue = Color(0xFFE9EEEA);
  static const canvas = Color(0xFFF3F4F1);

  void _demo(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$name — UI preview only; not connected to live records.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _panel(Widget child, {Color color = Colors.white}) => Container(
    padding: const EdgeInsets.all(23),
    decoration: BoxDecoration(color: color, border: Border.all(color: color == Colors.white ? const Color(0xFFE2E6E2) : Colors.transparent), borderRadius: BorderRadius.circular(18)),
    child: child,
  );

  Widget _tag(String text, {Color color = canvas}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
    child: Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
  );

  Widget _btn(BuildContext context, String label, IconData icon, {bool primary = true}) =>
    OutlinedButton.icon(
      onPressed: () => _demo(context, label),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: primary ? ink : Colors.white,
        foregroundColor: primary ? Colors.white : ink,
        side: primary ? BorderSide.none : const BorderSide(color: Color(0xFFE7EAE7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );

  Widget _stat(String label, String value, String detail, Color color, IconData icon) =>
      _panel(SizedBox(height: 118, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF6B777A), fontSize: 11))),
            Icon(icon, size: 18, color: ink),
          ]),
          Text(value, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w600, letterSpacing: -.8)),
          Text(detail, style: const TextStyle(color: Color(0xFF62706A), fontSize: 10)),
        ],
      )), color: color);

  Widget _stats(List<(String, String, String, Color, IconData)> list) =>
      LayoutBuilder(builder: (context, c) {
        final columns = c.maxWidth > 1020 ? 4 : c.maxWidth > 570 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 4 ? 1.85 : columns == 2 ? 2.5 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final item in list) _stat(item.$1, item.$2, item.$3, item.$4, item.$5)],
        );
      });

  Widget _table(List<String> headers, List<List<String>> rows) => _panel(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Recent records', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text('Example records for visual review only', style: TextStyle(fontSize: 10.5, color: muted)),
      const SizedBox(height: 18),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        headingRowHeight: 43,
        dataRowMinHeight: 49,
        dataRowMaxHeight: 53,
        horizontalMargin: 12,
        columnSpacing: 38,
        headingTextStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 10),
        dataTextStyle: const TextStyle(color: ink, fontWeight: FontWeight.w500, fontSize: 11),
        columns: [for (final h in headers) DataColumn(label: Text(h.toUpperCase()))],
        rows: [for (final r in rows) DataRow(cells: [for (final v in r) DataCell(Text(v))])],
      )),
    ],
  ));

  Widget _actionPanel(BuildContext context, String heading, String explanation,
      List<(String, IconData)> actions, {Color color = Colors.white}) =>
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(heading, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        Text(explanation, style: const TextStyle(fontSize: 11, color: muted, height: 1.7)),
        const SizedBox(height: 19),
        Wrap(spacing: 9, runSpacing: 9, children: [
          for (final a in actions) _btn(context, a.$1, a.$2, primary: false),
        ]),
      ]), color: color);

  Widget _excel(BuildContext context) => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 46, height: 46, decoration: BoxDecoration(color: lavender, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.table_view_rounded, color: ink)),
      const SizedBox(width: 13),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Import existing products', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        SizedBox(height: 3),
        Text('Excel / CSV column mapping to be configured later', style: TextStyle(color: muted, fontSize: 10.5)),
      ])),
    ]),
    const SizedBox(height: 18),
    Container(width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: canvas, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E5DE))),
      child: const Column(children: [
        Icon(Icons.upload_file_outlined, size: 29, color: ink),
        SizedBox(height: 10),
        Text('Excel import placeholder', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        SizedBox(height: 5),
        Text('Future: upload → map columns → preview changes → approve', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 10.5)),
      ])),
    const SizedBox(height: 12),
    _btn(context, 'Choose Excel file', Icons.file_upload_outlined),
  ]));

  // Compact, vertical denomination list. This remains a visual-only form.
  // Compact, vertical denomination list. This remains a visual-only form.
  Widget _denominations(BuildContext context) => _panel(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Cash denomination count', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 15),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: canvas, borderRadius: BorderRadius.circular(9)),
        child: const Row(children: [
          Expanded(child: Text('DENOMINATION', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10))),
          SizedBox(width: 90, child: Text('PIECES', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10))),
        ])),
      for (final d in ['₱1,000', '₱500', '₱200', '₱100', '₱50', '₱20', '₱10', '₱5', '₱1', '₱0.25'])
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE8EBEF)))),
          child: Row(children: [
            Expanded(child: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            SizedBox(width: 90, height: 32, child: TextField(keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              decoration: InputDecoration(hintText: '0', isDense: true, filled: true, fillColor: canvas,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide.none)))),
          ])),
      const SizedBox(height: 13),
      _btn(context, 'Preview reconciliation', Icons.calculate_outlined),
    ],
  ));

  Widget _logbook(BuildContext context) => _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('New logbook entry', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
    const SizedBox(height: 7),
    const Text('Mobile load, supplier payments, cash transfers, and shift notes', style: TextStyle(color: muted, fontSize: 11)),
    const SizedBox(height: 17),
    Wrap(spacing: 10, runSpacing: 10, children: [for (final cat in ['Mobile load', 'Supplier payment', 'Petty cash', 'Cash in/out', 'General note']) _tag(cat, color: lavender)]),
    const SizedBox(height: 16),
    TextField(decoration: InputDecoration(hintText: 'Amount (optional)', filled: true, fillColor: canvas, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
    const SizedBox(height: 12),
    TextField(maxLines: 3, decoration: InputDecoration(hintText: 'Write a note for this shift...', filled: true, fillColor: canvas, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
    const SizedBox(height: 14),
    _btn(context, 'Save entry (demo)', Icons.add_rounded),
  ]));

  @override
  Widget build(BuildContext context) {
    final cashier = !admin;
    final description = <String, String>{
      'Products': 'Manage the product catalogue and prepare legacy Excel imports.',
      'Inventory': 'Monitor stock levels, adjustments and replenishment.',
      'Price management': 'Review purchase costs, markups and selling price updates.',
      'Suppliers': 'Keep purchasing and delivery records organized.',
      'Analytics': 'Explore sales performance, trends and profitability.',
      'Cash reconciliation': 'Review cashier differences and counter closing reports.',
      'Settings': 'Manage staff, terminals, permissions and backups.',
      'Transactions': 'Look up completed cashier transactions and authorized refunds.',
      'Receipt history': 'Locate previous invoices and request reprints.',
      'Cash denominations': 'Count the drawer and preview end-of-shift reconciliation.',
      
      
    }[title] ?? 'Workspace preview';

    final metrics = <String, List<(String, String, String, Color, IconData)>>{
      'Products': [('Active products','2,468','Across all categories',lime,Icons.inventory_2_outlined),('Categories','34','Organized inventory',Colors.white,Icons.category_outlined),('Price updates','18','Pending review',lavender,Icons.sell_outlined),('Unmapped items','12','From previous exports',blue,Icons.merge_type_outlined)],
      'Inventory': [('Stock units','18,240','Available units',lime,Icons.warehouse_outlined),('Low stock','24','Require restocking',lavender,Icons.warning_amber_outlined),('Received today','362','Sample quantities',Colors.white,Icons.move_to_inbox_outlined),('Adjustments','7','Current week',blue,Icons.tune_outlined)],
      'Price management': [('Changed this week','18','Selling prices',lime,Icons.price_change_outlined),('Avg. markup','22.5%','Illustrative figure',lavender,Icons.percent),('Pending review','6','Needs approval',Colors.white,Icons.pending_actions_outlined),('Cost increases','12','Supplier updates',blue,Icons.trending_up_rounded)],
      'Suppliers': [('Suppliers','16','Active accounts',lime,Icons.local_shipping_outlined),('Deliveries','8','Today',Colors.white,Icons.inventory_outlined),('Outstanding','₱18,420','Example balance',lavender,Icons.payments_outlined),('New invoices','4','Awaiting review',blue,Icons.receipt_long_outlined)],
      'Analytics': [('Sales today','₱84,295','Across three counters',lime,Icons.payments_outlined),('Transactions','328','Example count',Colors.white,Icons.receipt_long_outlined),('Items sold','1,482','Sample volume',lavender,Icons.shopping_bag_outlined),('Gross margin','21.4%','Illustrative estimate',blue,Icons.trending_up_rounded)],
      'Cash reconciliation': [('Expected cash','₱46,800','Across all counters',lime,Icons.account_balance_wallet_outlined),('Cash counted','₱46,770','Example totals',Colors.white,Icons.payments_outlined),('Difference','−₱30','Combined shortage',lavender,Icons.balance_outlined),('Pending close','1','Counter not closed',blue,Icons.schedule_outlined)],
      'Settings': [('Terminals','3','Configured counters',lime,Icons.desktop_windows_outlined),('Staff accounts','12','Example users',Colors.white,Icons.people_outline),('Backups','Daily','Planned schedule',lavender,Icons.backup_outlined),('Permissions','4','Role templates',blue,Icons.admin_panel_settings_outlined)],
      'Transactions': [('My sales','₱12,450','Current shift',lime,Icons.payments_outlined),('Transactions','46','Completed today',Colors.white,Icons.receipt_long_outlined),('Refunds','1','Awaiting approval',lavender,Icons.assignment_return_outlined),('Voids','0','Current shift',blue,Icons.block_outlined)],
      'Receipt history': [('Issued today','46','Sample invoices',lime,Icons.receipt_long_outlined),('Reprints','2','Authorized copies',lavender,Icons.print_outlined),('Last invoice','000046','Example sequence',Colors.white,Icons.numbers_outlined),('My counter','02','Assigned terminal',blue,Icons.point_of_sale_outlined)],
      'Cash denominations': [('Opening float','₱2,000','Current shift',lime,Icons.account_balance_wallet_outlined),('Cash sales','₱12,450','Sample transactions',Colors.white,Icons.payments_outlined),('Cash pickups','₱5,000','Example movement',lavender,Icons.outbox_outlined),('Expected cash','₱9,450','Example balance',blue,Icons.calculate_outlined)],
      'Cashier logbook': [('Entries today','8','Current shift',lime,Icons.edit_note_outlined),('Load collections','₱580','Illustrative amount',Colors.white,Icons.phone_android_outlined),('Cash payouts','₱320','Illustrative amount',lavender,Icons.payments_outlined),('Notes','3','Shift observations',blue,Icons.notes_outlined)],
      'My shift': [('Counter','02','Assigned terminal',lime,Icons.point_of_sale_outlined),('Shift started','08:00 AM','Example time',Colors.white,Icons.schedule_outlined),('Sales','₱12,450','Sample total',lavender,Icons.payments_outlined),('Transactions','46','Sample count',blue,Icons.receipt_long_outlined)],
    };
    final rows = <String, List<List<String>>>{
      'Products': [['4800012345678','Coca-Cola 1.5L','Beverages','₱78.00','124'],['4800098765432','Piattos Cheese','Snacks','₱30.00','42'],['4800024681357','Pancit Canton','Noodles','₱20.00','96']],
      'Inventory': [['Coca-Cola 1.5L','124','24','In stock'],['Piattos Cheese','8','20','Low stock'],['Pancit Canton','96','30','In stock']],
      'Price management': [['Piattos Cheese','₱28.00','₱30.00','+7.14%'],['Coca-Cola 1.5L','₱75.00','₱78.00','+4.00%'],['Nova BBQ','₱26.00','₱26.00','0.00%']],
      'Suppliers': [['Suysing','DR-1023','Today','Received'],['Supplier B','INV-2401','Yesterday','Pending'],['Supplier C','DR-1021','Yesterday','Received']],
      'Analytics': [['Beverages','₱21,400','25.4%','↑'],['Snacks','₱17,800','21.1%','↑'],['Noodles','₱12,100','14.3%','→']],
      'Cash reconciliation': [['Counter 01','₱14,200','₱14,200','Balanced'],['Counter 02','₱17,100','₱17,070','−₱30'],['Counter 03','₱15,500','₱15,500','Balanced']],
      'Settings': [['Counter 01','Cashier terminal','Active','Demo'],['Counter 02','Cashier terminal','Active','Demo'],['Counter 03','Cashier terminal','Active','Demo']],
      'Transactions': [['TX-00218','10:42 AM','Cash','₱358.00'],['TX-00217','10:38 AM','Cash','₱145.00'],['TX-00216','10:32 AM','E-wallet','₱612.00']],
      'Receipt history': [['INV-000046','10:42 AM','₱358.00','Issued'],['INV-000045','10:38 AM','₱145.00','Issued'],['INV-000044','10:32 AM','₱612.00','Issued']],
      'Cash denominations': [['Cash pickup','09:45 AM','−₱5,000','Approved'],['Opening float','08:00 AM','+₱2,000','Confirmed']],
      'Cashier logbook': [['Mobile load','10:12 AM','₱100.00','Cash in'],['Supplier payment','09:50 AM','₱200.00','Cash out'],['Shift note','08:30 AM','—','Note']],
      'My shift': [['Shift opened','08:00 AM','Cashier 02','Complete'],['Cash pickup','09:45 AM','Supervisor','Approved'],['Shift closing','05:00 PM','Pending','Upcoming']],
    };
    final headers = <String, List<String>>{
      'Products': ['Barcode','Product','Category','Price','Stock'],
      'Inventory': ['Product','Stock','Reorder','Status'],
      'Price management': ['Product','Old price','New price','Change'],
      'Suppliers': ['Supplier','Reference','Date','Status'],
      'Analytics': ['Category','Sales','Share','Trend'],
      'Cash reconciliation': ['Counter','Expected','Counted','Difference'],
      'Settings': ['Terminal','Type','Status','Environment'],
      'Transactions': ['Transaction','Time','Payment','Total'],
      'Receipt history': ['Invoice','Time','Amount','Status'],
      'Cash denominations': ['Movement','Time','Amount','Status'],
      'Cashier logbook': ['Entry','Time','Amount','Impact'],
      'My shift': ['Activity','Time','By','Status'],
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w600, letterSpacing: -.9)),
          if (title != 'Cash denominations') ...[
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(color: muted, fontSize: 11.5)),
          ],
        ])),
        if (cashier && title == 'Cash denominations') Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE3E8DF)), borderRadius: BorderRadius.circular(12)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, color: Color(0xFF87C439), size: 8),
            SizedBox(width: 8),
            Text('COUNTER 01', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .3)),
          ]),
        ),
        if (admin) _tag('ADMIN WORKSPACE', color: lavender),
      ]),
      const SizedBox(height: 25),
      if (metrics[title] != null) _stats(metrics[title]!),
      const SizedBox(height: 16),
      if (title == 'Products') ...[
        _excel(context), const SizedBox(height: 16),
        _actionPanel(context,'Product management','Create and organize products after connecting the database.', [('Add product',Icons.add),('Export products',Icons.download_outlined),('Categories',Icons.category_outlined)]),
      ] else if (title == 'Cash denominations') ...[
        LayoutBuilder(builder: (context, constraints) => constraints.maxWidth >= 740
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 4, child: _denominations(context)),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: _table(headers[title]!, rows[title]!)),
            ])
          : Column(children: [
              _denominations(context),
              const SizedBox(height: 16),
              _table(headers[title]!, rows[title]!),
            ])),
        const SizedBox(height: 16),
      ] else if (title == 'Cashier logbook') ...[
        _logbook(context), const SizedBox(height: 16),
      ] else if (title == 'Price management') ...[
        _actionPanel(context,'Price change workspace','Proposed prices will be reviewed before publishing to all three counters.', [('New price update',Icons.sell_outlined),('Bulk change',Icons.percent),('Price history',Icons.history)],color: const Color(0xFFF0EEFF)),
        const SizedBox(height: 16),
      ] else ...[
        _actionPanel(context, '$title tools', description, [
          (title == 'Transactions' ? 'Filter transactions' : title == 'Receipt history' ? 'Find invoice' : title == 'My shift' ? 'Close shift (demo)' : 'Create new (demo)', Icons.add_circle_outline),
          ('Export / print', Icons.file_download_outlined),
        ], color: const Color(0xFFEDF0ED)),
        const SizedBox(height: 16),
      ],
      if (title != 'Cash denominations' && rows[title] != null && headers[title] != null) _table(headers[title]!, rows[title]!),
      const SizedBox(height: 20),
      const Text('All values and controls on this page are illustrative. No database changes are performed.', style: TextStyle(color: muted, fontSize: 10)),
    ]);
  }
}
