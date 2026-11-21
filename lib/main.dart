import 'cash_denominations_page.dart';
import 'keyboard_pos.dart';
import 'workspace_pages.dart';
import 'admin_products_page.dart';
import 'admin_workspaces.dart';
import 'ionyk_brand.dart';
import 'ionyk_api.dart';
import 'transactions_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IonykBrand.instance.load();
  runApp(const IonykApp());
}

class Palette {
  static const bg = Color(0xFFF3F4F1);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF171B1C);
  static const muted = Color(0xFF687272);
  static const border = Color(0xFFE2E6E2);
  static const lime = Color(0xFFD9FF57);
  static const lavender = Color(0xFFE8F1DC);
  static const blue = Color(0xFFE9EEEA);
  static const green = Color(0xFF477F28);
  static const dark = Color(0xFF151A1A);
  static const peach = Color(0xFFE8F8B8);
  static const orange = Color(0xFFD9FF57);
  static const sidebar = Color(0xFF151A1A);
}

class IonykApp extends StatelessWidget {
  const IonykApp({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: IonykBrand.instance,
    builder: (context, _) => MaterialApp(
        title: 'IONYK Systems',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: Palette.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: IonykBrand.instance.accent, surface: Palette.paper),
          textTheme: GoogleFonts.dmSansTextTheme().apply(bodyColor: Palette.ink, displayColor: Palette.ink),
          useMaterial3: true,
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            titleTextStyle: const TextStyle(color: Palette.ink, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -.35),
            contentTextStyle: const TextStyle(color: Palette.muted, fontSize: 12, height: 1.6),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true, fillColor: const Color(0xFFF5F6F3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E6E2))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF91B532), width: 1.5)),
          ),
          filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
            backgroundColor: Palette.dark, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          )),
        ),
        home: const LoginPage(),
      ),
  );
}

enum UserRole { admin, cashier }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  UserRole role = UserRole.admin;
  final username = TextEditingController();
  final password = TextEditingController();
  bool hide = true;
  bool signingIn = false;
  String? loginError;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Widget _roleOption(UserRole option, IconData icon, String name, String subtitle) {
    final active = role == option;
    return Expanded(child: InkWell(
      onTap: () => setState(() => role = option),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: active ? Palette.lavender.withValues(alpha: .42) : Palette.bg,
          border: Border.all(color: active ? const Color(0xFFAAA6DA) : Palette.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, color: Palette.ink, size: 20),
            Icon(active ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 17, color: active ? Palette.green : Palette.muted),
          ]),
          const SizedBox(height: 15),
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Palette.muted, fontSize: 10)),
        ]),
      ),
    ));
  }

  Widget _loginForm() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 430),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const IonykBrandMark(size: 38),
        const SizedBox(width: 11),
        const IonykBrandName(dark: false),
      ]),
      const SizedBox(height: 51),
      const Text('Made for the way\nyou work.', style: TextStyle(fontSize: 30, height: 1.25, fontWeight: FontWeight.w600, letterSpacing: -.9)),
      const SizedBox(height: 11),
      const Text('One thoughtfully designed workspace. Sign in to explore.', style: TextStyle(color: Palette.muted, fontSize: 12)),
      const SizedBox(height: 30),
      const Text('SELECT WORKSPACE', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, letterSpacing: .7, color: Color(0xFF647076))),
      const SizedBox(height: 10),
      Row(children: [
        _roleOption(UserRole.admin, Icons.dashboard_customize_outlined, 'Administration', 'Manage operations'),
        const SizedBox(width: 12),
        _roleOption(UserRole.cashier, Icons.point_of_sale_outlined, 'Cashier', 'Checkout & records'),
      ]),
      const SizedBox(height: 23),
      const Text('Username', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 7),
      TextField(controller: username, decoration: InputDecoration(hintText: 'Enter your username', prefixIcon: const Icon(Icons.person_outline_rounded, size: 19), filled: true, fillColor: Palette.bg, contentPadding: const EdgeInsets.symmetric(vertical: 17), enabledBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Palette.green), borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 17),
      const Text('Password', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 7),
      TextField(controller: password, obscureText: hide, onSubmitted: (_) => _enter(), decoration: InputDecoration(hintText: 'Enter your password', prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19), filled: true, fillColor: Palette.bg, contentPadding: const EdgeInsets.symmetric(vertical: 17), enabledBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Palette.green), borderRadius: BorderRadius.circular(12)), suffixIcon: IconButton(tooltip: 'Toggle password visibility', onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18)))),
      const SizedBox(height: 23),
      SizedBox(height: 52, child: FilledButton(
        onPressed: signingIn ? null : _enter,
        style: FilledButton.styleFrom(backgroundColor: Palette.dark, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Enter workspace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), SizedBox(width: 13), Icon(Icons.arrow_forward_rounded, size: 17)]),
      )),
      const SizedBox(height: 20),
      if (loginError != null) Text(loginError!, style: const TextStyle(color: Colors.redAccent, fontSize: 11), textAlign: TextAlign.center),
      const Text('Local development login · The backend validates usernames and passwords.', style: TextStyle(color: Palette.muted, fontSize: 9.5), textAlign: TextAlign.center),
    ]),
  );

  Future<void> _enter() async {
    if (signingIn) return;
    setState(() { signingIn=true; loginError=null; });
    try {
      final result = await const IonykApi().login(username.text.trim(),password.text);
      final actualRole = result['role'] == 'admin' ? UserRole.admin : UserRole.cashier;
      if (role != actualRole) {
        await const IonykApi().logout();
        throw Exception('Select the correct workspace for this account.');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => DashboardShell(role: actualRole)));
    } catch (e) { if (mounted) setState(() => loginError='Login failed: $e'); }
    finally { if (mounted) setState(() => signingIn=false); }
  }

  Widget _brandPanel() => Container(
    padding: const EdgeInsets.all(48),
    decoration: const BoxDecoration(color: Palette.dark),
    child: Stack(children: [
      Positioned(right: -135, top: 70, child: Container(width: 390, height: 390, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF4C5D43), width: 1.4)))),
      Positioned(right: -77, top: 124, child: Container(width: 270, height: 270, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF4C5D43), width: 1.4)))),
      Positioned(right: 34, top: 200, child: Container(width: 108, height: 108, decoration: const BoxDecoration(shape: BoxShape.circle, color: Palette.lime))),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.all_inclusive_rounded, color: Palette.orange, size: 30), SizedBox(width: 12), Text('IONYK / SYSTEMS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: .2))]),
        const Spacer(),
        Container(width: 54, height: 5, decoration: BoxDecoration(color: Palette.lime, borderRadius: BorderRadius.circular(5))),
        const SizedBox(height: 22),
        const Text('Control,\nwithout the\nclutter.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 43, height: 1.2, letterSpacing: -1.5)),
        const SizedBox(height: 22),
        const SizedBox(width: 350, child: Text('The essentials, in focus. Sales, products and decisions — all in one workspace.', style: TextStyle(color: Color(0xFFBDC6C2), fontSize: 12, height: 1.85))),
        const SizedBox(height: 50),
        Row(children: [
          Container(width: 9, height: 9, decoration: const BoxDecoration(shape: BoxShape.circle, color: Palette.orange)),
          const SizedBox(width: 8),
          const Text('DESIGNED FOR FOCUS', style: TextStyle(color: Color(0xFFC8D1CB), fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 1)),
        ]),
      ]),
    ]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 950;
      return Row(children: [
        if (wide) Expanded(flex: 48, child: _brandPanel()),
        Expanded(flex: 52, child: Container(
          color: Palette.paper,
          child: Center(child: SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: wide ? 58 : 24, vertical: 30), child: _loginForm())),
        )),
      ]);
    }),
  );
}

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.role});
  final UserRole role;
  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int tab = 0;
  String search = '';
  bool get admin => widget.role == UserRole.admin;
  List<String> get pages => admin
    ? ['Overview', 'Products', 'Inventory', 'Suppliers', 'Analytics', 'Cash reconciliation', 'Settings']
    : ['Point of sale', 'Transactions', 'Cash closing'];
  Future<void> _signOut() async {
    await const IonykApi().logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder:(_)=>const LoginPage()));
  }
  List<IconData> get icons => admin
    ? [Icons.grid_view_rounded, Icons.inventory_2_outlined, Icons.warehouse_outlined, Icons.local_shipping_outlined, Icons.bar_chart_rounded, Icons.account_balance_wallet_outlined, Icons.settings_outlined]
    : [Icons.point_of_sale_rounded, Icons.receipt_long_rounded, Icons.payments_outlined];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 1080;
      return Scaffold(
        body: Row(children: [
          if (!narrow) _sidebar(),
          Expanded(child: Column(children: [
            _topbar(narrow),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(34, 30, 34, 34), child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: admin && tab == 0 ? _overview(constraints.maxWidth - (narrow ? 60 : 320)) : (admin ? _detailPage() : _cashierPage()),
            ))),
          ])),
        ]),
      );
    });
  }

  Widget _sidebar() => Container(
        width: 238,
        decoration: const BoxDecoration(color: Palette.sidebar),
        padding: const EdgeInsets.fromLTRB(16, 27, 16, 17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(children: [
            const IonykBrandMark(size: 36),
            const SizedBox(width: 10),
            const Expanded(child: IonykBrandName()),
          ])),
          const SizedBox(height: 46),
          const Padding(padding: EdgeInsets.only(left: 12, bottom: 13), child: Text('WORKSPACE', style: TextStyle(fontSize: 10, color: Color(0xFF979CA5), fontWeight: FontWeight.w600, letterSpacing: 1))),
          for (int i = 0; i < pages.length; i++) _nav(i),
          const Spacer(),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF262D2D), borderRadius: BorderRadius.circular(12)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.circle, size: 8, color: Color(0xFFD9FF57)), SizedBox(width: 9), Text('LOCAL SERVER', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 10, letterSpacing: .4))]),
            SizedBox(height: 8), Text('Connection preview', style: TextStyle(fontSize: 10, color: Color(0xFFC0C5CB))),
          ])),
          const SizedBox(height: 10),
          _SidebarSignOutButton(onPressed: _signOut),
        ]),
      );

  Widget _nav(int i) {
    final active = tab == i;
    return Padding(padding: const EdgeInsets.only(bottom: 5), child: InkWell(
      onTap: () => setState(() => tab = i), borderRadius: BorderRadius.circular(11),
      child: Container(height: 42, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(
        color: active ? const Color(0xFF303A37) : Colors.transparent, borderRadius: BorderRadius.circular(11)),
        child: Row(children: [
          Icon(icons[i], size: 17, color: active ? IonykBrand.instance.accent : const Color(0xFFB4C1BC)),
          const SizedBox(width: 12),
          Expanded(child: Text(pages[i], style: TextStyle(fontSize: 12.5, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? IonykBrand.instance.accent : const Color(0xFFDAE4DD)))),
          if (active) Container(width: 4, height: 4, decoration: BoxDecoration(color: IonykBrand.instance.accent, shape: BoxShape.circle)),
        ]),
      ),
    ));
  }

  Widget _topbar(bool narrow) => Container(
    height: 70,
    decoration: const BoxDecoration(color: Palette.paper, border: Border(bottom: BorderSide(color: Palette.border))),
    padding: const EdgeInsets.symmetric(horizontal: 34),
    child: Row(children: [
      if (narrow) PopupMenuButton<int>(
        icon: const Icon(Icons.menu),
        onSelected: (i) => setState(() => tab = i),
        itemBuilder: (_) => [
          for (int i = 0; i < pages.length; i++) PopupMenuItem(value: i, child: Text(pages[i])),
        ],
      ),
      Text(pages[tab], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      if (narrow && !admin) ...[const SizedBox(width: 10), Flexible(child: Text(IonykApi.currentDisplayName ?? IonykApi.currentUsername ?? 'Cashier', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Palette.muted)))],
      const Spacer(),
      if (!narrow) Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Palette.bg, borderRadius: BorderRadius.circular(20)),
        child: Text(admin ? 'ADMIN WORKSPACE' : '${IonykApi.currentDisplayName ?? IonykApi.currentUsername ?? 'Cashier'} · Counter ${IonykApi.currentTerminalId?.toString().padLeft(2, '0') ?? '--'}', style: const TextStyle(color: Palette.muted, fontSize: 9.5, letterSpacing: .2, fontWeight: FontWeight.w600)),
      ),
      // Small-window fallback: sidebar is hidden, so sign out remains accessible.
      if (narrow) _SidebarSignOutButton(onPressed: _signOut),
    ]),
  );

  Future<Map<String,dynamic>>? _overviewRequest;
  Future<Map<String,dynamic>> get _stats =>
      _overviewRequest ??= const IonykApi().testOverview();

  Widget _overview(double width) => FutureBuilder<Map<String,dynamic>>(
    future:_stats,
    builder:(ctx,snapshot) {
      final stats=snapshot.data;
      final counters=((stats?['counters'] as List?)??const [])
        .map((e)=>Map<String,dynamic>.from(e as Map)).toList();
      final gross=double.tryParse('${stats?['gross_sales']??0}')??0;
      final active=counters.where((c)=>c['live']==true).length;
      final entries=<(String,String,IconData)>[
        ('Gross sales', '₱${gross.toStringAsFixed(2)}', Icons.payments_outlined),
        ('Transactions', '${stats?['transactions']??0}', Icons.receipt_long_outlined),
        ('Items sold', '${stats?['items_sold']??0}', Icons.shopping_bag_outlined),
        ('Gross profit', '--', Icons.trending_up_outlined),
        ('Stock value', '--', Icons.inventory_2_outlined),
        ('Low stock', '--', Icons.warning_amber_outlined),
        ('Active counters', '$active', Icons.point_of_sale_outlined),
        ('Cash variance', '--', Icons.balance_outlined),
      ];
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const Expanded(child:Text('Business overview',style:TextStyle(fontSize:27,fontWeight:FontWeight.w600))),
          TextButton.icon(onPressed:(){setState(()=>_overviewRequest=null);},
            icon:const Icon(Icons.refresh,size:16),label:const Text('Refresh stats')),
        ]),
        const SizedBox(height:5),
        const Text('DEVELOPMENT TEST SALES ONLY · not official store revenue',
          style:TextStyle(color:Palette.muted,fontSize:11)),
        if(snapshot.hasError) Padding(padding:const EdgeInsets.only(top:8),child:
          Text('Stats unavailable: ${snapshot.error}',style:const TextStyle(color:Colors.red))),
        const SizedBox(height:18),
        LayoutBuilder(builder:(context,constraints){
          final columns=constraints.maxWidth>=950?4:constraints.maxWidth>=530?2:1;
          return Column(children:[
            for(int row=0;row<entries.length;row+=columns)
              Padding(padding:const EdgeInsets.only(bottom:12),child:Row(children:[
                for(int i=row;i<row+columns;i++) ...[
                  if(i>row)const SizedBox(width:12),
                  Expanded(child:i<entries.length?_metric(entries[i].$1,entries[i].$2,'',
                    'Development test data',Colors.white,entries[i].$3):const SizedBox()),
                ],
              ])),
          ]);
        }),
        const SizedBox(height:10),
        LayoutBuilder(builder:(context,constraints){
          final wide=constraints.maxWidth>=840;
          final performance=_surface(child:Padding(padding:const EdgeInsets.all(22),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Sales performance',style:TextStyle(fontSize:15,fontWeight:FontWeight.w600)),
            const SizedBox(height:5),
            const Text('Test sales total · weekly graph pending real time-series API',
              style:TextStyle(fontSize:11,color:Palette.muted)),
            const SizedBox(height:14),
            Text('₱${gross.toStringAsFixed(2)}',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w600)),
            const SizedBox(height:14),
            SizedBox(height:135,width:double.infinity,child:CustomPaint(painter:_FlatZeroLinePainter())),
            const SizedBox(height:8),
            Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
              for(final day in ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'])
                Text(day,style:const TextStyle(fontSize:10,color:Palette.muted)),
            ]),
          ])));
          final liveCard=Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(
            color:Palette.dark,borderRadius:BorderRadius.circular(18)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[const Expanded(child:Text('Live counters',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:15))),
                Text('$active active',style:const TextStyle(color:Palette.lime,fontSize:11))]),
              const SizedBox(height:18),
              if(counters.isEmpty)const Text('No counters created',style:TextStyle(color:Colors.white70)),
              ...counters.map((c){
                final sale=double.tryParse('${c['sales']??0}')??0;
                final portion=gross>0?(sale/gross).clamp(0.0,1.0):0.0;
                return Padding(padding:const EdgeInsets.only(bottom:15),child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[Expanded(child:Text('${c['label']} · ${c['display_name']??''}',
                    overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:11))),
                    Text(c['live']==true?'Live':'Offline',style:TextStyle(fontSize:10,
                      color:c['live']==true?Palette.lime:Colors.white54))]),
                  const SizedBox(height:5),
                  Text('₱${sale.toStringAsFixed(2)} test sales',style:const TextStyle(color:Colors.white70,fontSize:10)),
                  const SizedBox(height:7),
                  ClipRRect(borderRadius:BorderRadius.circular(5),child:LinearProgressIndicator(
                    minHeight:6,value:portion,backgroundColor:const Color(0xFF354239),valueColor:const AlwaysStoppedAnimation<Color>(Palette.lime))),
                ]));
              }),
              const Text('Live = recent activity within 5 minutes; refresh to update.',
                style:TextStyle(color:Colors.white54,fontSize:9)),
            ]));
          if(wide)return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Expanded(flex:3,child:performance),const SizedBox(width:12),
            Expanded(flex:2,child:liveCard),
          ]);
          return Column(children:[performance,const SizedBox(height:12),liveCard]);
        }),
      ]);
    },
  );

  Widget _surface({required Widget child, Color color = Palette.paper}) => Container(decoration: BoxDecoration(color: color, border: Border.all(color: color == Palette.paper ? Palette.border : Colors.transparent), borderRadius: BorderRadius.circular(18)), child: child);
  Widget _metric(String label, String value, String change, String caption, Color color, IconData icon) => _surface(color: color, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Color(0xFF626B6F), fontSize: 11, fontWeight: FontWeight.w500)), Icon(icon, size: 18, color: Palette.dark)]),
    Text(value, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w600, letterSpacing: -.7)),
    Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(change, style: const TextStyle(color: Palette.green, fontSize: 10.5, fontWeight: FontWeight.w700)), Text(caption, style: const TextStyle(color: Color(0xFF737D81), fontSize: 10))]),
  ])));

  Widget _salesChart() => _surface(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sales performance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), SizedBox(height: 5), Text('Revenue trend over the last 7 days', style: TextStyle(color: Palette.muted, fontSize: 11))])), _chip('Last 7 days', Icons.keyboard_arrow_down)]),
    const SizedBox(height: 16),
    const Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('₱482,650', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w600, letterSpacing: -.7)), SizedBox(width: 10), Padding(padding: EdgeInsets.only(bottom: 6), child: Text('↗ 14.2%', style: TextStyle(fontSize: 11, color: Palette.green, fontWeight: FontWeight.w700)))]),
    const SizedBox(height: 12),
    SizedBox(height: 140, width: double.infinity, child: CustomPaint(painter: SalesPainter())),
    const SizedBox(height: 6),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) Text(day, style: TextStyle(color: Palette.muted, fontSize: 10))]),
  ])));

  Widget _counterCard() => _surface(color: Palette.dark, child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Live counters', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF393F47), borderRadius: BorderRadius.circular(15)), child: const Text('●  All online', style: TextStyle(color: Palette.lime, fontSize: 10)))]),
    const SizedBox(height: 7), const Text('Real-time transaction overview', style: TextStyle(color: Color(0xFFBEC9C3), fontSize: 10.5)),
    const SizedBox(height: 20),
    _counter('Counter 01', '₱29,480', 0.86, Palette.orange),
    const SizedBox(height: 16), _counter('Counter 02', '₱31,215', 0.93, Palette.lavender),
    const SizedBox(height: 16), _counter('Counter 03', '₱23,600', 0.69, Palette.blue),
    const SizedBox(height: 15), const Divider(color: Color(0xFF3A4348)),
    const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total today', style: TextStyle(color: Color(0xFFBEC9C3), fontSize: 11)), Text('₱84,295', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14))]),
  ])));
  Widget _counter(String title, String value, double progress, Color color) => Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 11)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))]), const SizedBox(height: 7), ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: const Color(0xFF434B4F), color: color))]);

  Widget _productsTable() => _surface(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Top-selling products', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), SizedBox(height: 4), Text('Products performing best this week', style: TextStyle(fontSize: 10.5, color: Palette.muted))]), TextButton(onPressed: () => setState(() => tab = 1), child: const Text('View all ↗', style: TextStyle(fontSize: 11, color: Palette.green)))]),
    const SizedBox(height: 18),
    const Row(children: [Expanded(flex: 5, child: Text('PRODUCT', style: TextStyle(fontSize: 9, color: Palette.muted))), Expanded(flex: 2, child: Text('SOLD', style: TextStyle(fontSize: 9, color: Palette.muted))), Expanded(flex: 2, child: Text('REVENUE', style: TextStyle(fontSize: 9, color: Palette.muted))), Text('TREND', style: TextStyle(fontSize: 9, color: Palette.muted))]),
    const SizedBox(height: 8),
    _product('Coca-Cola 1.5L', 'Beverages', '182', '₱14,196', '+12%', Palette.lavender),
    _product('Piattos Cheese 85g', 'Snacks', '146', '₱4,380', '+8%', Palette.lime),
    _product('Lucky Me Pancit Canton', 'Noodles', '132', '₱2,640', '+6%', Palette.blue),
    _product('Nescafé Classic 50g', 'Coffee', '118', '₱9,440', '+15%', const Color(0xFFF7DFCD)),
  ])));
  Widget _product(String name, String category, String sold, String revenue, String trend, Color color) => Container(padding: const EdgeInsets.symmetric(vertical: 9), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.border))), child: Row(children: [
    Expanded(flex: 5, child: Row(children: [Container(width: 33, height: 33, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.local_mall_outlined, size: 17)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)), Text(category, style: const TextStyle(fontSize: 9, color: Palette.muted))]))])),
    Expanded(flex: 2, child: Text(sold, style: const TextStyle(fontSize: 10.5))), Expanded(flex: 2, child: Text(revenue, style: const TextStyle(fontSize: 10.5))),
    Text(trend, style: const TextStyle(fontSize: 10, color: Palette.green, fontWeight: FontWeight.w700)),
  ]));
  Widget _activityCard() => _surface(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Recent activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4), const Text('What’s happening in your store', style: TextStyle(color: Palette.muted, fontSize: 10.5)),
    const SizedBox(height: 17),
    _activity(Icons.point_of_sale_rounded, 'Sale completed', 'Counter 02 · ₱1,245.00', '2m ago', Palette.lime),
    _activity(Icons.sell_outlined, 'Price updated', 'Coca-Cola 1.5L · ₱78.00', '14m ago', Palette.lavender),
    _activity(Icons.local_shipping_outlined, 'Stock received', 'Supplier delivery · 46 items', '38m ago', Palette.blue),
    _activity(Icons.warning_amber_rounded, 'Low stock alert', 'Piattos Cheese · 8 remaining', '1h ago', const Color(0xFFF9E3CE)),
  ])));
  Widget _activity(IconData icon, String name, String desc, String time, Color color) => Padding(padding: const EdgeInsets.only(bottom: 17), child: Row(children: [Container(width: 35, height: 35, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 17)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)), Text(desc, style: const TextStyle(fontSize: 9.5, color: Palette.muted))])), Text(time, style: const TextStyle(fontSize: 9, color: Palette.muted))]));

  void _showImportPlaceholder() => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
    title: const Text('Import products from Excel'),
    content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Text('Import workflow placeholder', style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(height: 10),
      Text('1. Choose an .xlsx or .csv product file\n2. Map spreadsheet columns to product fields\n3. Match existing barcodes and review duplicates\n4. Preview added and changed products\n5. Confirm updates and record an audit trail', style: TextStyle(fontSize: 12, height: 1.9)),
      SizedBox(height: 15), Text('The required columns are not defined yet. No file is read or imported in this prototype.', style: TextStyle(fontSize: 11, color: Palette.muted)),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
  ));

  Widget _cashierPage() {
    if (tab == 0) return const KeyboardPos();
    if (tab == 1) return const TransactionsPage();
    if (tab == 2) return const CashDenominationsPage();
    return WorkspacePages(title: pages[tab], admin: false);
  }

  Widget _detailPage() => pages[tab] == 'Products' ? const AdminProductsPage() : AdminWorkspacePage(title: pages[tab]);

  Widget _button(String name, IconData icon, {bool dark = true, VoidCallback? onTap}) =>
      SizedBox(height: 40, child: OutlinedButton.icon(
        onPressed: onTap ?? () { ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name is a preview action.'))); },
        icon: Icon(icon, size: 16), label: Text(name),
        style: OutlinedButton.styleFrom(
          backgroundColor: dark ? Palette.dark : Colors.white,
          foregroundColor: dark ? const Color(0xFFD9FF57) : Palette.ink,
          side: dark ? BorderSide.none : const BorderSide(color: Color(0xFFE0E5DF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ));
  Widget _chip(String label, IconData icon) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Palette.bg, borderRadius: BorderRadius.circular(10)), child: Row(children: [Text(label, style: const TextStyle(fontSize: 10.5)), const SizedBox(width: 5), Icon(icon, size: 14)]));
}

class SalesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = Palette.border..strokeWidth = 1;
    for (var y = 0; y < 4; y++) {
      final py = size.height * (y + 1) / 5;
      canvas.drawLine(Offset(0, py), Offset(size.width, py), gridPaint);
    }
    final vals = [0.64, .43, .56, .28, .37, .17, .11];
    final step = size.width / (vals.length - 1);
    final path = Path()..moveTo(0, size.height * vals[0]);
    for (var i = 1; i < vals.length; i++) {
      final prevX = step * (i - 1); final x = step * i; final cx = (prevX + x) / 2;
      path.cubicTo(cx, size.height * vals[i - 1], cx, size.height * vals[i], x, size.height * vals[i]);
    }
    final area = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(area, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66D9FF57), Color(0x00D9FF57)]).createShader(Offset.zero & size));
    canvas.drawPath(path, Paint()..color = const Color(0xFF769B25)..strokeWidth = 2.8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    for (var i = 0; i < vals.length; i++) {
      canvas.drawCircle(Offset(i * step, size.height * vals[i]), 3.5, Paint()..color = Palette.paper);
      canvas.drawCircle(Offset(i * step, size.height * vals[i]), 2.5, Paint()..color = const Color(0xFF769B25));
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// Sidebar action: soft red hover and unmistakable sign-out affordance.
class _SidebarSignOutButton extends StatefulWidget {
  const _SidebarSignOutButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  State<_SidebarSignOutButton> createState() => _SidebarSignOutButtonState();
}

class _SidebarSignOutButtonState extends State<_SidebarSignOutButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: Material(
      color: hovered ? const Color(0xFF5C262A) : const Color(0xFF262D2D),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onPressed,
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.max, children: [
              Icon(Icons.logout_rounded, size: 17,
                  color: hovered ? const Color(0xFFFFB0B3) : const Color(0xFFC2C8D1)),
              const SizedBox(width: 11),
              Text('Sign out', style: TextStyle(fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: hovered ? const Color(0xFFFFB0B3) : const Color(0xFFE3E6EB))),
            ]),
          ),
        ),
      ),
    ),
  );
}

// Flat baseline only — this is a visual empty state, not fabricated sales data.
class _FlatZeroLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()..color = const Color(0xFFE8ECE8)..strokeWidth = 1;
    for (final y in [0.0, .33, .66, 1.0]) {
      canvas.drawLine(Offset(0, size.height * y), Offset(size.width, size.height * y), guide);
    }
    final baseline = Paint()..color = const Color(0xFF8BA83B)..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * .95), Offset(size.width, size.height * .95), baseline);
  }
  @override
  bool shouldRepaint(covariant _FlatZeroLinePainter oldDelegate) => false;
}
