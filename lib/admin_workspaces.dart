import 'package:flutter/material.dart';
import 'ionyk_brand.dart';

const _ink = Color(0xFF171B1C);
const _muted = Color(0xFF6D7772);
const _line = Color(0xFFE0E5DF);
const _bg = Color(0xFFF3F4F1);
const _dark = Color(0xFF151B1A);

/// Admin-only interface previews. Figures and actions are mock data; no ledger
/// changes, fiscal closures, staff accounts or server operations occur here.
class AdminWorkspacePage extends StatefulWidget {
  const AdminWorkspacePage({super.key, required this.title});
  final String title;
  @override
  State<AdminWorkspacePage> createState() => _AdminWorkspacePageState();
}

class _AdminWorkspacePageState extends State<AdminWorkspacePage> {
  String query = '';
  String status = 'All';
  int selectedRow = -1;
  String analyticsWindow = 'Last 7 days';

  @override
  void didUpdateWidget(covariant AdminWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      query = '';
      status = 'All';
      selectedRow = -1;
    }
  }

  void demo(String action) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('$action — preview only. No records were changed.'),
    ));
  }

  Widget card(Widget child, {Color color = Colors.white, EdgeInsetsGeometry padding = const EdgeInsets.all(19)}) => Container(
    padding: padding,
    decoration: BoxDecoration(color: color, border: Border.all(color: color == Colors.white ? _line : Colors.transparent), borderRadius: BorderRadius.circular(17)),
    child: child,
  );

  Widget sectionTitle(String title, String subtitle, {Widget? trailing}) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600, letterSpacing: -.6)),
      const SizedBox(height: 5), Text(subtitle, style: const TextStyle(fontSize: 11, color: _muted)),
    ])),
    if (trailing != null) trailing,
  ]);

  // One size and visual language for all Admin header actions.
  Widget button(String text, IconData icon, {bool primary = false, VoidCallback? action}) =>
      SizedBox(
        height: 40,
        child: OutlinedButton.icon(
          onPressed: action ?? () => demo(text),
          icon: Icon(icon, size: 16),
          label: Text(text),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            backgroundColor: primary ? _dark : Colors.white,
            foregroundColor: primary ? IonykBrand.instance.accent : _ink,
            side: primary ? BorderSide.none : const BorderSide(color: _line),
            textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );

  // Branded pop-up selector instead of Windows/Material's default grey menu.
  Widget selectMenu({
    required String value,
    required List<String> options,
    required ValueChanged<String> onSelected,
    double minWidth = 154,
  }) => PopupMenuButton<String>(
        tooltip: 'Choose filter',
        initialValue: value,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 5),
        elevation: 9,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: 230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13),
            side: const BorderSide(color: _line)),
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final option in options)
            PopupMenuItem<String>(
              value: option,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: option == value
                      ? IonykBrand.instance.accent.withValues(alpha: .25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Expanded(child: Text(option,
                    style: TextStyle(fontSize: 11.5, color: _ink,
                      fontWeight: option == value ? FontWeight.w700 : FontWeight.w500))),
                  if (option == value) const Icon(Icons.check_rounded, size: 16, color: _ink),
                ]),
              ),
            ),
        ],
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: _line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.tune_rounded, size: 15, color: _muted),
            const SizedBox(width: 8),
            Text(value, style: const TextStyle(fontSize: 11.5, color: _ink,
              fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _muted),
          ]),
        ),
      );

  Widget stat(String label, String amount, String context, {Color? tint, IconData icon = Icons.insights_outlined}) => Expanded(
    child: card(Container(
      constraints: const BoxConstraints(minHeight: 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: _muted))), Icon(icon, color: _ink, size: 16)]),
        Text(amount, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -.6)),
        Text(context, style: const TextStyle(fontSize: 10, color: _muted)),
      ]),
    ), color: tint ?? Colors.white),
  );

  Widget metrics(List<(String, String, String, IconData)> entries) => LayoutBuilder(builder: (context, c) {
    final cols = c.maxWidth >= 960 ? 4 : c.maxWidth >= 500 ? 2 : 1;
    return Column(children: [
      for (int start = 0; start < entries.length; start += cols)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (int i = start; i < start + cols; i++) ...[
            if (i > start) const SizedBox(width: 12),
            if (i < entries.length) stat(entries[i].$1, entries[i].$2, entries[i].$3, tint: i == 0 ? IonykBrand.instance.accent : null, icon: entries[i].$4) else const Expanded(child: SizedBox()),
          ],
        ])),
    ]);
  });

  Widget filterBar({bool statusPicker = true}) => Row(children: [
    Expanded(child: SizedBox(height: 40, child: TextField(
      key: ValueKey(widget.title),
      onChanged: (v) => setState(() { query = v; selectedRow = -1; }),
      style: const TextStyle(fontSize: 12, color: _ink),
      decoration: InputDecoration(
        hintText: 'Search by product, reference, supplier or counter',
        hintStyle: const TextStyle(fontSize: 11, color: _muted),
        prefixIcon: const Icon(Icons.search_rounded, size: 17, color: _muted),
        filled: true, fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      ),
    ))),
    if (statusPicker) ...[
      const SizedBox(width: 10),
      selectMenu(
        value: status,
        options: switch (widget.title) {
          'Inventory' => ['All', 'In stock', 'Low stock'],
          'Suppliers' => ['All', 'Pending', 'Received'],
          'Cash reconciliation' => ['All', 'Balanced', 'Short', 'Over'],
          _ => ['All', 'In stock', 'Low stock', 'Pending', 'Received', 'Balanced', 'Short', 'Over'],
        },
        onSelected: (v) => setState(() { status = v; selectedRow = -1; }),
      ),
    ],
  ]);

  Widget dataGrid({required String title, required String caption, required List<String> columns, required List<List<String>> rows, bool filter = true}) => card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4), Text(caption, style: const TextStyle(fontSize: 10, color: _muted)),
    ])), Text('${rows.length} rows', style: const TextStyle(fontSize: 10, color: _muted))]),
    if (filter) ...[const SizedBox(height: 17), filterBar()],
    const SizedBox(height: 12),
    LayoutBuilder(builder: (context, c) {
      final visible = rows.asMap().entries.where((r) {
        final text = r.value.join(' ').toLowerCase();
        final matchesQuery = text.contains(query.toLowerCase().trim());
        final matchesStatus = status == 'All' || text.contains(status.toLowerCase());
        return matchesQuery && matchesStatus;
      }).toList();
      final width = c.maxWidth > columns.length * 130 ? c.maxWidth : columns.length * 130.0;
      return Scrollbar(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(
        width: width,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(_bg),
          headingRowHeight: 42, dataRowMinHeight: 52, dataRowMaxHeight: 56,
          horizontalMargin: 13, columnSpacing: 22,
          border: const TableBorder(horizontalInside: BorderSide(color: _line)),
          headingTextStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _muted),
          dataTextStyle: const TextStyle(fontSize: 11, color: _ink),
          showCheckboxColumn: false,
          columns: [for (final h in columns) DataColumn(label: Text(h.toUpperCase(), maxLines: 2))],
          rows: [for (final item in visible) DataRow(
            selected: selectedRow == item.key,
            onSelectChanged: (_) => setState(() => selectedRow = item.key),
            color: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? IonykBrand.instance.accent.withValues(alpha: .23) : Colors.white),
            cells: [for (final value in item.value) DataCell(Text(value, overflow: TextOverflow.ellipsis))],
          )],
        ),
      )));
    }),
    if (rows.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 9), child: Text('Select any row to highlight it. All figures are example data.', style: TextStyle(color: _muted, fontSize: 10))),
  ]));

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: IonykBrand.instance,
    builder: (context, _) => switch (widget.title) {
      'Inventory' => inventory(),
      'Suppliers' => suppliers(),
      'Analytics' => analytics(),
      'Cash reconciliation' => reconciliation(),
      'Settings' => settings(),
      _ => const SizedBox.shrink(),
    },
  );

  Widget inventory() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    sectionTitle('Inventory', 'Track what is physically available, received, sold and adjusted.', trailing: button('Receive stock', Icons.add_box_outlined, primary: true)),
    const SizedBox(height: 18),
    metrics([
      ('Stock on hand','18,240 pcs','Across all tracked products',Icons.inventory_2_outlined),
      ('Low-stock items','24','Below minimum levels',Icons.warning_amber_outlined),
      ('Received today','362 pcs','Supplier deliveries',Icons.move_to_inbox_outlined),
      ('Stock adjustments','7','This week',Icons.tune_rounded),
    ]),
    const SizedBox(height: 5),
    dataGrid(title: 'Inventory levels', caption: 'One stock record per product; cases convert to pieces', columns: ['Product / Barcode','Available pcs','Pcs / case','Reorder at','Status','Last activity'], rows: [
      ['Coca-Cola 1.5L · 4800012345678','124','12','24','In stock','Received today'],
      ['Piattos Cheese · 4800098765432','8','24','20','Low stock','Sold today'],
      ['Lucky Me Pancit Canton','96','72','30','In stock','Received yesterday'],
      ['Nescafé Classic 50g','25','1','20','In stock','Sold today'],
      ['Nova BBQ','5','24','18','Low stock','Sold yesterday'],
    ]),
    const SizedBox(height: 14),
    card(Row(children: [const Icon(Icons.info_outline, color: _muted), const SizedBox(width: 12), const Expanded(child: Text('For the future backend: stock is tracked in pieces. Receiving 2 cases of 12 adds 24 pieces; selling one case deducts 12.', style: TextStyle(fontSize: 11, color: _muted))), button('Record adjustment', Icons.edit_note_outlined)])),
  ]);

  Widget suppliers() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    sectionTitle('Suppliers', 'Know where products come from and what the store pays.', trailing: button('Add supplier', Icons.add_rounded, primary: true)),
    const SizedBox(height: 18),
    metrics([
      ('Active suppliers','3','Linked to products',Icons.local_shipping_outlined),
      ('Latest delivery','Today','Last receiving entry',Icons.move_to_inbox_outlined),
      ('Products linked','148','Example catalogue links',Icons.inventory_outlined),
      ('Cost changes','8','Recorded this month',Icons.trending_up_rounded),
    ]),
    const SizedBox(height: 5),
    dataGrid(title:'Supplier directory', caption:'Supplier costs may vary even for the same product', columns:['Supplier','Contact','Products','Last delivery','Recent document','Status'], rows:[
      ['Suysing','09XX XXX XXXX','86','Nov 19, 2026','DR-1023','Received'],
      ['Supplier B','09XX XXX XXXX','42','Nov 17, 2026','INV-2401','Pending'],
      ['Supplier C','09XX XXX XXXX','20','Nov 15, 2026','DR-1021','Received'],
    ]),
    const SizedBox(height: 14),
    card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Supplier purchasing tools',style:TextStyle(fontSize:14,fontWeight:FontWeight.w600)),const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:[button('Receive delivery',Icons.inventory_outlined),button('Review purchase costs',Icons.price_check_outlined),button('Match supplier product names',Icons.merge_type_rounded)]),const SizedBox(height:10),const Text('Supplier records, purchase invoices and multi-supplier product matching will connect to the backend later.',style:TextStyle(fontSize:10,color:_muted))])),
  ]);

  Widget analytics() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    sectionTitle('Analytics', 'Store performance, sales trends and estimated profitability.',
      trailing: selectMenu(value: analyticsWindow,
        options: const ['Today', 'Last 7 days', 'Last 30 days'],
        onSelected: (v) => setState(() => analyticsWindow = v))),
    const SizedBox(height: 18),
    metrics([
      ('Gross sales','₱84,295','Illustrative sample',Icons.payments_outlined),
      ('Transactions','328','All three counters',Icons.receipt_long_outlined),
      ('Items sold','1,482','Across categories',Icons.shopping_bag_outlined),
      ('Estimated gross profit','₱18,040','Before operating expenses',Icons.insights_outlined),
    ]),
    const SizedBox(height: 5),
    LayoutBuilder(builder:(context,c){
      final narrow=c.maxWidth<800;
      final graph=card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Sales trend',style:TextStyle(fontSize:14,fontWeight:FontWeight.w600)),const SizedBox(height:5),const Text('Illustrative performance; not calculated from actual sales',style:TextStyle(fontSize:10,color:_muted)),const SizedBox(height:22),
        SizedBox(height:180,child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[for(final entry in <(String,double)>[('M',.47),('T',.64),('W',.58),('T',.81),('F',.68),('S',.95),('S',.77)]) Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:7),child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[Expanded(child:Align(alignment:Alignment.bottomCenter,child:FractionallySizedBox(heightFactor:entry.$2,child:Container(decoration:BoxDecoration(color:IonykBrand.instance.accent,borderRadius:const BorderRadius.vertical(top:Radius.circular(8))))))),const SizedBox(height:9),Text(entry.$1,style:const TextStyle(fontSize:10,color:_muted))])))])),
      ]));
      final categories=card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Sales by category',style:TextStyle(fontSize:14,fontWeight:FontWeight.w600)),const SizedBox(height:21),for(final e in <(String,double,String)>[('Beverages',.74,'₱21,400'),('Snacks',.58,'₱17,800'),('Noodles',.37,'₱12,100'),('Coffee',.24,'₱8,720')])...[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(e.$1,style:const TextStyle(fontSize:11)),Text(e.$3,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600))]),const SizedBox(height:7),LinearProgressIndicator(value:e.$2,minHeight:8,borderRadius:BorderRadius.circular(6),color:IonykBrand.instance.accent,backgroundColor:_bg),const SizedBox(height:19)
      ]]));
      return narrow?Column(children:[graph,const SizedBox(height:14),categories]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:6,child:graph),const SizedBox(width:14),Expanded(flex:4,child:categories)]);
    }),
    const SizedBox(height:14),
    dataGrid(title:'Best-selling products',caption:'See what moves fastest in your store',filter:false,columns:['Product','Units sold','Sales amount','Estimated gross profit','Trend'],rows:[
      ['Coca-Cola 1.5L','182','₱14,196','₱2,366','+12%'],
      ['Piattos Cheese','146','₱4,380','₱1,022','+8%'],
      ['Lucky Me Pancit Canton','132','₱2,640','₱660','+6%'],
      ['Nescafé Classic','118','₱9,440','₱2,006','+15%'],
    ]),
  ]);

  Widget reconciliation() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    sectionTitle('Cash reconciliation','Compare POS-expected cash with each cashier’s counted denominations.',trailing:button('Export closing report',Icons.file_download_outlined,primary:true)),
    const SizedBox(height:18),
    metrics([
      ('Expected cash','₱46,800','All counters',Icons.account_balance_wallet_outlined),
      ('Counted cash','₱46,770','Cash denomination totals',Icons.payments_outlined),
      ('Net difference','−₱30','Store-wide shortage',Icons.balance_outlined),
      ('Open closing','1','Needs review',Icons.pending_actions_outlined),
    ]),
    const SizedBox(height:5),
    LayoutBuilder(builder:(context,c){final cols=c.maxWidth>820?3:1;final counters=<({String id,String cashier,String expected,String counted,String diff,bool issue})>[
      (id:'01',cashier:'Cashier 1',expected:'₱14,200',counted:'₱14,200',diff:'₱0',issue:false),
      (id:'02',cashier:'Cashier 2',expected:'₱17,100',counted:'₱17,070',diff:'−₱30',issue:true),
      (id:'03',cashier:'Cashier 3',expected:'₱15,500',counted:'₱15,500',diff:'₱0',issue:false),
    ];
    Widget counter(int i) {final x=counters[i];return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text('Counter ${x.id}',style:const TextStyle(fontSize:15,fontWeight:FontWeight.w600))),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:x.issue?const Color(0xFFFFF1DD):const Color(0xFFEBF4DD),borderRadius:BorderRadius.circular(9)),child:Text(x.issue?'SHORT':'BALANCED',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w700)))]),
      const SizedBox(height:3),Text(x.cashier,style:const TextStyle(fontSize:10,color:_muted)),const SizedBox(height:15),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Expected',style:TextStyle(fontSize:11,color:_muted)),Text(x.expected,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600))]),const SizedBox(height:9),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Counted',style:TextStyle(fontSize:11,color:_muted)),Text(x.counted,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600))]),const Divider(height:25),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Difference',style:TextStyle(fontSize:11)),Text(x.diff,style:TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:x.issue?const Color(0xFFAC4A2D):_ink))]),
    ]));}
    return cols==3?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[for(int i=0;i<3;i++)...[if(i>0)const SizedBox(width:12),Expanded(child:counter(i))]]):Column(children:[for(int i=0;i<3;i++)Padding(padding:const EdgeInsets.only(bottom:12),child:counter(i))]);}),
    const SizedBox(height:14),
    dataGrid(title:'Closing history',caption:'Cash counts, closing status and differences by terminal',columns:['Date','Counter','Cashier','Expected','Counted','Difference','Status'],rows:[
      ['Nov 19, 2026','Counter 01','Cashier 1','₱14,200','₱14,200','₱0','Balanced'],
      ['Nov 19, 2026','Counter 02','Cashier 2','₱17,100','₱17,070','−₱30','Short'],
      ['Nov 19, 2026','Counter 03','Cashier 3','₱15,500','₱15,500','₱0','Balanced'],
      ['Nov 18, 2026','Counter 01','Cashier 1','₱12,100','₱12,120','+₱20','Over'],
    ]),
    const SizedBox(height:14),
    card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('What the owner should review',style:TextStyle(fontSize:14,fontWeight:FontWeight.w600)),const SizedBox(height:10),const Text('Expected cash = opening float + cash sales + approved cash-in − refunds paid in cash − cash-outs. Cash difference = counted cash − expected cash. Review Z-Reading copies, approvals and denomination sheets before finalizing a discrepancy.',style:TextStyle(fontSize:11,color:_muted,height:1.6)),const SizedBox(height:11),Wrap(spacing:8,children:[button('View Z-Readings',Icons.receipt_long_outlined),button('Review adjustments',Icons.fact_check_outlined)] )])),
  ]);

  Widget settings() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    sectionTitle('Settings','Personalize the IONYK workspace and configure the store.',trailing:Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),decoration:BoxDecoration(borderRadius:BorderRadius.circular(10),color:IonykBrand.instance.accent),child:const Text('LOCAL APPEARANCE',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700)))),
    const SizedBox(height:18),
    LayoutBuilder(builder:(context,c){
      final left=card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Store branding',style:TextStyle(fontSize:15,fontWeight:FontWeight.w600)),const SizedBox(height:5),const Text('The logo replaces the IONYK mark in the sidebar and sign-in screen.',style:TextStyle(fontSize:11,color:_muted)),const SizedBox(height:17),
        Row(children:[IonykBrandMark(size:66),const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Current logo',style:TextStyle(fontSize:12,fontWeight:FontWeight.w600)),const SizedBox(height:4),const Text('PNG, JPG or WebP · under 1 MB',style:TextStyle(fontSize:10,color:_muted))]))]),
        const SizedBox(height:15),Wrap(spacing:8,runSpacing:8,children:[
          button('Choose logo',Icons.upload_file_outlined,primary:true,action:()async {final issue=await IonykBrand.instance.chooseLogo();if(issue!=null&&mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(issue)));}}),
          if(IonykBrand.instance.logo!=null)button('Remove logo',Icons.delete_outline,action:()=>IonykBrand.instance.clearLogo()),
        ]),
        const SizedBox(height: 20),
        const Text('Brand display name', style: TextStyle(fontSize:12,fontWeight:FontWeight.w600)),
        const SizedBox(height: 7),
        TextFormField(
          key: ValueKey(IonykBrand.instance.businessName),
          initialValue: IonykBrand.instance.businessName,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(hintText: 'IONYK SYSTEMS', helperText: 'Press Enter to apply'),
          onFieldSubmitted: (v) => IonykBrand.instance.setBusinessName(v),
        ),
        const SizedBox(height:22),const Text('Brand accent',style:TextStyle(fontSize:12,fontWeight:FontWeight.w600)),const SizedBox(height:9),
        for(final e in IonykBrand.instance.accents.entries)...[
          InkWell(onTap:()=>IonykBrand.instance.setAccent(e.key),borderRadius:BorderRadius.circular(10),child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:10),decoration:BoxDecoration(borderRadius:BorderRadius.circular(10),border:Border.all(color:IonykBrand.instance.selectedAccent==e.key?_ink:_line)),child:Row(children:[Container(width:22,height:22,decoration:BoxDecoration(color:e.value,borderRadius:BorderRadius.circular(7))),const SizedBox(width:11),Expanded(child:Text(e.key,style:const TextStyle(fontSize:11))),if(IonykBrand.instance.selectedAccent==e.key)const Icon(Icons.check_circle,size:18)]))),const SizedBox(height:7),
        ],
        const SizedBox(height:8),const Text('Accent changes apply to the navigation and these Admin dashboards. Some older POS and Products widgets still use fixed colors.',style:TextStyle(fontSize:10,color:_muted,height:1.55)),
      ]));
      final right=Column(children:[
        card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Preview',style:TextStyle(fontSize:15,fontWeight:FontWeight.w600)),const SizedBox(height:12),Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_dark,borderRadius:BorderRadius.circular(12)),child:Row(children:[IonykBrandMark(size:45),const SizedBox(width:12),Expanded(child:Text(IonykBrand.instance.businessName,style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w700))),Container(width:12,height:12,decoration:BoxDecoration(color:IonykBrand.instance.accent,shape:BoxShape.circle))])),const SizedBox(height:13),const Text('Appearance settings are saved on this computer only.',style:TextStyle(fontSize:10,color:_muted))])),
        const SizedBox(height:14),
        card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Business & terminals',style:TextStyle(fontSize:15,fontWeight:FontWeight.w600)),const SizedBox(height:13),for(final row in <(String,String,IconData)>[('Business details','Business name, address, TIN and registered information',Icons.storefront_outlined),('Counter configuration','Counter 01, Counter 02, Counter 03',Icons.desktop_windows_outlined),('Staff & permissions','Admin and Cashier roles, password policies',Icons.people_outline),('Backup & restore','Scheduled database backups and recovery tests',Icons.backup_outlined),('Audit log','Price changes, void approvals and publishing actions',Icons.history_outlined)])Padding(padding:const EdgeInsets.only(bottom:9),child:InkWell(onTap:()=>demo(row.$1),child:Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:_bg,borderRadius:BorderRadius.circular(10)),child:Row(children:[Icon(row.$3,size:19,color:_ink),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(row.$1,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600)),const SizedBox(height:3),Text(row.$2,style:const TextStyle(fontSize:10,color:_muted))])),const Icon(Icons.chevron_right,size:17,color:_muted)]))))])),
      ]);
      return c.maxWidth>780?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:4,child:left),const SizedBox(width:14),Expanded(flex:6,child:right)]):Column(children:[left,const SizedBox(height:14),right]);
    }),
  ]);
}
