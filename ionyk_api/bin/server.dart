import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypt;

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

// Development only. Bound to 127.0.0.1 so remote devices cannot call it.
// Add authentication and authorization before exposing the API to your LAN.
Future<void> main() async {
  final password = Platform.environment['IONYK_DB_PASSWORD'];
  if (password == null || password.isEmpty) {
    stderr.writeln('Set IONYK_DB_PASSWORD before starting the API.');
    exitCode = 1;
    return;
  }
  final connection = await Connection.open(
    Endpoint(
      host: '127.0.0.1',
      port: 5432,
      database: 'ionyk_dev',
      username: 'postgres',
      password: password,
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );
  // Session tokens are volatile and disappear when the API restarts.
  final sessions = <String, ({int userId, String role, int? terminalId, DateTime expiry})>{};
  final rng = Random.secure();
  String newToken() => base64UrlEncode(List<int>.generate(32, (_) => rng.nextInt(256)));
  final seedPassword = Platform.environment['IONYK_BOOTSTRAP_ADMIN_PASSWORD'];
  if (seedPassword != null && seedPassword.isNotEmpty) {
    final existing = await connection.execute('SELECT count(*) FROM app_users');
    if ((existing.first[0] as int) == 0) {
      final salt = newToken();
      final hash = passwordHash(seedPassword, salt);
      await connection.execute(Sql.named("""INSERT INTO app_users
        (username,password_salt,password_hash,role)
        VALUES ('admin01',@salt,@hash,'admin')"""),
        parameters: {'salt': salt, 'hash': hash});
      stdout.writeln('Created initial Admin account: admin01');
    }
  }
  final router = Router();
  ({int userId, String role, int? terminalId, DateTime expiry})? sessionFor(Request request) {
    final auth = request.headers['authorization'] ?? '';
    if (!auth.startsWith('Bearer ')) return null;
    final token = auth.substring(7);
    final session = sessions[token];
    if (session == null) return null;
    if (DateTime.now().isAfter(session.expiry)) { sessions.remove(token); return null; }
    return session;
  }

  router.post('/login', (Request request) async {
    Map<String,dynamic> body;
    try { body = Map<String,dynamic>.from(jsonDecode(await request.readAsString()) as Map); }
    catch (_) { return jsonResponse({'error': 'Invalid JSON'}, status: 400); }
    final username = (body['username'] ?? '').toString().trim().toLowerCase();
    final password = (body['password'] ?? '').toString();
    final result = await connection.execute(Sql.named("""SELECT id, password_salt, password_hash,
      role, terminal_id, display_name FROM app_users WHERE username = @username AND active = true"""),
      parameters: {'username':username});
    if (result.isEmpty) return jsonResponse({'error':'Invalid credentials'},status:401);
    final user = result.first.toColumnMap();
    if (!safeEqual(passwordHash(password, user['password_salt'] as String), user['password_hash'] as String)) {
      return jsonResponse({'error':'Invalid credentials'},status:401);
    }
    final role = user['role'] as String;
    final terminalId = user['terminal_id'] as int?;
    if (role == 'cashier') {
      if (terminalId == null) return jsonResponse({'error':'No counter assigned'},status:403);
      final activeCounter = await connection.execute(Sql.named(
        'SELECT is_active FROM terminals WHERE id=@id'), parameters: {'id':terminalId});
      if (activeCounter.isEmpty || activeCounter.first[0] != true) {
        return jsonResponse({'error':'This counter is deactivated. Contact Admin.'},status:403);
      }
    }
    if (role=='cashier') {
      await connection.execute(Sql.named('UPDATE terminals SET last_seen_at=now() WHERE id=@id'),parameters:{'id':terminalId});
    }
    final token = newToken();
    sessions[token] = (userId: user['id'] as int, role: role, terminalId: terminalId,
      expiry: DateTime.now().add(const Duration(hours: 8)));
    return jsonResponse({'token':token,'role':role,'username':username,'display_name':(user['display_name'] as String? ?? '').trim().isEmpty ? username : user['display_name'],'terminal_id':terminalId});
  });
  // Admin password change: requires a live Admin session and its current password.
  router.post('/admin/change-credentials', (Request request) async {
    final session = sessionFor(request);
    if (session == null || session.role != 'admin') {
      return jsonResponse({'error':'Admin login required'},status:403);
    }
    Map<String,dynamic> body;
    try { body=Map<String,dynamic>.from(jsonDecode(await request.readAsString()) as Map); }
    catch (_) { return jsonResponse({'error':'Invalid JSON'},status:400); }
    final newUser=(body['new_username']??'').toString().trim().toLowerCase();
    final oldPassword=(body['current_password']??'').toString();
    final newPassword=(body['new_password']??'').toString();
    if (!RegExp(r'^[a-z0-9_]{1,32}$').hasMatch(newUser) || newPassword.isEmpty) {
      return jsonResponse({'error':'Enter a valid username and a nonempty password'},status:400);
    }
    final rows=await connection.execute(Sql.named('''SELECT password_salt,password_hash
      FROM app_users WHERE id=@id AND role='admin' AND active=true'''),
      parameters:{'id':session.userId});
    if (rows.isEmpty || !safeEqual(passwordHash(oldPassword, rows.first[0] as String),rows.first[1] as String)) {
      return jsonResponse({'error':'Current Admin password is incorrect'},status:403);
    }
    final salt=newToken();
    try {
      await connection.execute(Sql.named('''UPDATE app_users SET username=@username,
        password_salt=@salt,password_hash=@hash WHERE id=@id'''),parameters:{
        'username':newUser,'salt':salt,'hash':passwordHash(newPassword,salt),'id':session.userId});
    } catch (_) { return jsonResponse({'error':'Username is already taken'},status:409); }
    sessions.removeWhere((_,x)=>x.userId==session.userId);
    return jsonResponse({'ok':true,'username':newUser,'message':'Sign in again with your new credentials'});
  });

  // Stage edits rather than changing live POS prices on Save. Admin-only via middleware.
  router.post('/products/<id>/draft', (Request request, String id) async {
    final productId = int.tryParse(id);
    if (productId == null || productId < 1) return jsonResponse({'error':'Invalid product ID'},status:400);
    final payload = await readDraftBody(request);
    if (payload is Response) return payload;
    final data = Map<String,dynamic>.from(payload as Map);
    try {
      final response=await connection.runTx((tx) async {
        final previous=await tx.execute(Sql.named('''SELECT b.barcode FROM products p
          JOIN product_barcodes b ON b.product_id=p.id AND b.unit='piece'
          WHERE p.id=@id AND NOT p.is_archived'''),parameters:{'id':productId});
        if (previous.isEmpty) throw StateError('Published product not found');
        if (previous.first[0] != data['piece_barcode']) throw StateError('The primary barcode cannot be changed in this version');
        final other=await tx.execute(Sql.named('''SELECT product_id FROM product_barcodes
          WHERE barcode=@code AND product_id<>@id'''),parameters:{'code':data['case_barcode'],'id':productId});
        if (other.isNotEmpty) throw StateError('Case barcode already belongs to another product');
        final result=await tx.execute(Sql.named('''INSERT INTO product_drafts (product_id,action,proposed_data)
          VALUES (@id,'update',CAST(@payload AS jsonb)) RETURNING id'''),parameters:{'id':productId,'payload':jsonEncode(data)});
        return {'id':result.first[0],'status':'pending'};
      });
      return jsonResponse(response,status:201);
    } catch(e) { return jsonResponse({'error':'Edit draft not saved: $e'},status:400); }
  });

  // List persisted development sales belonging to the logged-in cashier.
  router.get('/sales/test', (Request request) async {
    final viewer=sessionFor(request);
    if (viewer==null || viewer.role!='cashier') return jsonResponse({'error':'Cashier login required'},status:403);
    final rows=await connection.execute(Sql.named('''SELECT s.id,s.terminal_id,s.receipt_no,s.total,s.tendered,
      s.change_due,s.item_count,s.created_at FROM dev_test_sales s
      WHERE s.cashier_user_id=@user AND s.terminal_id=@counter
      ORDER BY s.created_at DESC,s.id DESC LIMIT 500'''),
      parameters:{'user':viewer.userId,'counter':viewer.terminalId});
    return jsonResponse(rows.map((r)=>{
      'id':r[0],'terminal_id':r[1],'receipt_no':r[2],'total':num.parse('${r[3]}'),
      'tendered':num.parse('${r[4]}'),'change_due':num.parse('${r[5]}'),
      'item_count':r[6],'created_at':r[7].toString(),'is_test':true,
    }).toList());
  });

  // Fetch a receipt-style record; authorization prevents cross-cashier access.
  router.get('/sales/test/<id>', (Request request,String id) async {
    final viewer=sessionFor(request);
    if (viewer==null || viewer.role!='cashier') return jsonResponse({'error':'Cashier login required'},status:403);
    final saleId=int.tryParse(id);
    if(saleId==null || saleId<1) return jsonResponse({'error':'Invalid receipt ID'},status:400);
    final sale=await connection.execute(Sql.named('''SELECT s.id,s.terminal_id,s.receipt_no,s.total,s.tendered,
      s.change_due,s.item_count,s.created_at,u.display_name
      FROM dev_test_sales s JOIN app_users u ON u.id=s.cashier_user_id
      WHERE s.id=@id AND s.cashier_user_id=@user AND s.terminal_id=@counter'''),
      parameters:{'id':saleId,'user':viewer.userId,'counter':viewer.terminalId});
    if(sale.isEmpty) return jsonResponse({'error':'Receipt not found'},status:404);
    final r=sale.first;
    final rows=await connection.execute(Sql.named('''SELECT COALESCE(l.description,p.description,'Grocery'),l.unit,l.quantity,
      l.unit_price,l.line_total FROM dev_test_sale_lines l
      LEFT JOIN products p ON p.id=l.product_id WHERE l.sale_id=@id ORDER BY l.id'''),parameters:{'id':saleId});
    return jsonResponse({
      'id':r[0],'terminal_id':r[1],'receipt_no':r[2],'total':num.parse('${r[3]}'),
      'tendered':num.parse('${r[4]}'),'change_due':num.parse('${r[5]}'),
      'item_count':r[6],'created_at':r[7].toString(),'cashier':r[8], 'is_test':true,
      'lines':rows.map((x)=>{
        'description':x[0],'unit':x[1],'quantity':x[2],
        'unit_price':num.parse('${x[3]}'),'line_total':num.parse('${x[4]}'),
      }).toList(),
    });
  });

  // Publish new product drafts atomically and route them to selected active counters.
  // Existing published product edits/archives are intentionally not supported yet.
  router.post('/publish', (Request request) async {
    final session=sessionFor(request);
    if (session == null || session.role!='admin') return jsonResponse({'error':'Admin required'},status:403);
    Map<String,dynamic> body;
    try { body=Map<String,dynamic>.from(jsonDecode(await request.readAsString()) as Map); }
    catch (_) { return jsonResponse({'error':'Invalid JSON'},status:400); }
    final rawDrafts=body['draft_ids'];
    final rawTargets=body['terminal_ids'];
    if (rawDrafts is! List || rawTargets is! List || rawDrafts.isEmpty || rawTargets.isEmpty ||
        rawDrafts.any((x)=>x is! int || x<1) || rawTargets.any((x)=>x is! int || x<1)) {
      return jsonResponse({'error':'Select at least one draft and one counter'},status:400);
    }
    final drafts=rawDrafts.cast<int>().toSet().toList()..sort();
    final targets=rawTargets.cast<int>().toSet().toList()..sort();
    try {
      final result=await connection.runTx((tx) async {
        // Serialize publishing to prevent duplicate barcode race conditions.
        await tx.execute('SELECT pg_advisory_xact_lock(719402)');
        for (final id in targets) {
          final t=await tx.execute(Sql.named('SELECT id FROM terminals WHERE id=@id AND is_active=true'),parameters:{'id':id});
          if (t.isEmpty) throw StateError('Counter $id does not exist or is inactive');
        }
        final items=<({int draftId,Map<String,dynamic> data})>[];
        final barcodes=<String>{};
        for (final id in drafts) {
          final r=await tx.execute(Sql.named("SELECT action,proposed_data,product_id FROM product_drafts WHERE id=@id AND status='pending' FOR UPDATE"),parameters:{'id':id});
          if (r.isEmpty || (r.first[0]!='create' && r.first[0]!='update')) throw StateError('Draft $id missing or action unsupported');
          final raw=r.first[1];
          final d=Map<String,dynamic>.from(raw is String ? jsonDecode(raw) as Map : raw as Map);
          if (r.first[0]=='update') {
            final productId=r.first[2] as int;
            final existingTargets=await tx.execute(Sql.named('''SELECT DISTINCT bt.terminal_id
              FROM publish_batch_targets bt
              JOIN publish_batch_drafts bd ON bd.batch_id=bt.batch_id
              JOIN product_drafts d ON d.id=bd.draft_id
              WHERE d.published_product_id=@id'''),parameters:{'id':productId});
            for(final target in existingTargets) {
              if(!targets.contains(target[0])) throw StateError(
                'Product edits must be published to all previously targeted counters because prices are shared');
            }
            items.add((draftId:id,data:d));
            continue;
          }
          for (final key in ['piece_barcode','case_barcode']) {
            final barcode=(d[key]??'').toString().trim();
            if (barcode.isEmpty) continue;
            if (!barcodes.add(barcode)) throw StateError('Duplicate barcode in selected drafts: $barcode');
            final existing=await tx.execute(Sql.named('SELECT 1 FROM product_barcodes WHERE barcode=@code'),parameters:{'code':barcode});
            if (existing.isNotEmpty) throw StateError('Barcode already published: $barcode');
          }
          items.add((draftId:id,data:d));
        }
        final batch=await tx.execute(Sql.named('INSERT INTO publish_batches (published_by,note) VALUES (@uid,@note) RETURNING id'),parameters:{'uid':session.userId,'note':'Phase 8 local development publishing'});
        final batchId=batch.first[0] as int;
        for (final target in targets) {
          await tx.execute(Sql.named("INSERT INTO publish_batch_targets (batch_id,terminal_id) VALUES (@batch,@counter)"),parameters:{'batch':batchId,'counter':target});
        }
        for (final item in items) {
          final d=item.data;
          final units=(d['selling_units']??'piece').toString();
          final qty=int.tryParse('${d['pieces_per_case']??1}')??1;
          final desc=(d['description']??'').toString().trim();
          final pieceCode=(d['piece_barcode']??'').toString().trim();
          final caseCode=(d['case_barcode']??'').toString().trim();
          final piecePrice=num.tryParse('${d['piece_price']}');
          final cost=num.tryParse('${d['supplier_cost_per_piece']}');
          final casePrice=num.tryParse('${d['case_price']}');
          if (desc.isEmpty || pieceCode.isEmpty || cost==null || cost<0 || piecePrice==null || piecePrice<0 ||
              !['piece','case','both'].contains(units) || qty<1 ||
              (units!='piece' && (casePrice==null || casePrice<0 || qty<2 || caseCode.isEmpty))) {
            throw StateError('Invalid data in draft ${item.draftId}');
          }
          int? supplierId;
          final supplier=(d['supplier']??'').toString().trim();
          if (supplier.isNotEmpty) {
            final r=await tx.execute(Sql.named('''INSERT INTO suppliers(name) VALUES (@name)
              ON CONFLICT (name) DO UPDATE SET name=EXCLUDED.name RETURNING id'''),parameters:{'name':supplier});
            supplierId=r.first[0] as int;
          }
          final draftType=await tx.execute(Sql.named(
            'SELECT action,product_id FROM product_drafts WHERE id=@id'),
            parameters:{'id':item.draftId});
          if (draftType.first[0]=='update') {
            final productId=draftType.first[1] as int;
            final oldPrices=await tx.execute(Sql.named(
              'SELECT unit,selling_price FROM product_prices WHERE product_id=@id'),
              parameters:{'id':productId});
            final old={for(final p in oldPrices) p[0] as String:num.parse('${p[1]}')};
            final oldCodes=await tx.execute(Sql.named(
              'SELECT unit,barcode FROM product_barcodes WHERE product_id=@id'),
              parameters:{'id':productId});
            final code={for(final b in oldCodes) b[0] as String:b[1] as String};
            if(code['piece']!=pieceCode) throw StateError('Primary barcode cannot change');
            if(caseCode.isNotEmpty && caseCode!=code['case']) {
              final clash=await tx.execute(Sql.named(
                'SELECT 1 FROM product_barcodes WHERE barcode=@code AND product_id<>@id'),
                parameters:{'code':caseCode,'id':productId});
              if(clash.isNotEmpty) throw StateError('Case barcode in use');
            }
            await tx.execute(Sql.named('''UPDATE products SET description=@desc,
              category=@category,supplier_id=@supplier,pieces_per_case=@qty,
              sell_piece=@sellPiece,sell_case=@sellCase,
              supplier_cost_per_piece=@cost,updated_at=now() WHERE id=@id'''),parameters:{
              'id':productId,'desc':desc,'category':(d['category']??'').toString(),
              'supplier':supplierId,'qty':qty,'sellPiece':units!='case',
              'sellCase':units!='piece','cost':cost});
            for(final entry in <(String,double)>[('piece',piecePrice.toDouble()),
              ('case',(casePrice??0).toDouble())]) {
              final unit=entry.$1;final amount=entry.$2;
              final enabled=unit=='piece'?units!='case':units!='piece';
              if(enabled) {
                await tx.execute(Sql.named('''INSERT INTO product_prices
                  (product_id,unit,selling_price) VALUES (@id,@unit,@price)
                  ON CONFLICT(product_id,unit) DO UPDATE SET selling_price=EXCLUDED.selling_price,
                    effective_at=now()'''),parameters:{'id':productId,'unit':unit,'price':amount});
                if(old[unit]!=amount) await tx.execute(Sql.named('''INSERT INTO price_history
                  (product_id,unit,old_price,new_price,publish_batch_id)
                  VALUES (@id,@unit,@old,@price,@batch)'''),parameters:{
                    'id':productId,'unit':unit,'old':old[unit],'price':amount,'batch':batchId});
              } else {
                await tx.execute(Sql.named(
                  'DELETE FROM product_prices WHERE product_id=@id AND unit=@unit'),
                  parameters:{'id':productId,'unit':unit});
              }
            }
            if(caseCode.isNotEmpty) {
              await tx.execute(Sql.named('''INSERT INTO product_barcodes
                (product_id,unit,barcode) VALUES (@id,'case',@code)
                ON CONFLICT (product_id,unit,barcode) DO NOTHING'''),
                parameters:{'id':productId,'code':caseCode});
              if(code['case']!=null && code['case']!=caseCode) {
                await tx.execute(Sql.named('''DELETE FROM product_barcodes
                  WHERE product_id=@id AND unit='case' AND barcode=@old'''),
                  parameters:{'id':productId,'old':code['case']});
              }
            }
            await tx.execute(Sql.named('''UPDATE product_drafts SET status='published',
              published_product_id=@product,published_at=now() WHERE id=@draft'''),
              parameters:{'product':productId,'draft':item.draftId});
            await tx.execute(Sql.named('INSERT INTO publish_batch_drafts(batch_id,draft_id) VALUES (@batch,@draft)'),
              parameters:{'batch':batchId,'draft':item.draftId});
            continue;
          }
          final prod=await tx.execute(Sql.named('''INSERT INTO products
            (description,category,supplier_id,pieces_per_case,sell_piece,sell_case,supplier_cost_per_piece)
            VALUES (@desc,@category,@supplier,@qty,@sellPiece,@sellCase,@cost) RETURNING id'''),
            parameters:{'desc':desc,'category':(d['category']??'').toString(), 'supplier':supplierId,
              'qty':qty,'sellPiece':units!='case','sellCase':units!='piece','cost':cost});
          final productId=prod.first[0] as int;
          // Keep the piece barcode as the canonical product barcode for catalogue searches.
          await tx.execute(Sql.named("INSERT INTO product_barcodes(product_id,unit,barcode) VALUES (@id,'piece',@code)"),parameters:{'id':productId,'code':pieceCode});
          if (units!='case') {
            await tx.execute(Sql.named("INSERT INTO product_prices(product_id,unit,selling_price) VALUES (@id,'piece',@price)"),parameters:{'id':productId,'price':piecePrice});
            await tx.execute(Sql.named("INSERT INTO price_history(product_id,unit,new_price,publish_batch_id) VALUES (@id,'piece',@price,@batch)"),parameters:{'id':productId,'price':piecePrice,'batch':batchId});
          }
          if (units!='piece') {
            await tx.execute(Sql.named("INSERT INTO product_barcodes(product_id,unit,barcode) VALUES (@id,'case',@code)"),parameters:{'id':productId,'code':caseCode});
            await tx.execute(Sql.named("INSERT INTO product_prices(product_id,unit,selling_price) VALUES (@id,'case',@price)"),parameters:{'id':productId,'price':casePrice});
            await tx.execute(Sql.named("INSERT INTO price_history(product_id,unit,new_price,publish_batch_id) VALUES (@id,'case',@price,@batch)"),parameters:{'id':productId,'price':casePrice,'batch':batchId});
          }
          await tx.execute(Sql.named("UPDATE product_drafts SET published_product_id=@product,status='published',published_at=now() WHERE id=@draft"),parameters:{'product':productId,'draft':item.draftId});
          await tx.execute(Sql.named('INSERT INTO publish_batch_drafts(batch_id,draft_id) VALUES (@batch,@draft)'),parameters:{'batch':batchId,'draft':item.draftId});
        }
        return {'batch_id':batchId,'published':items.length,'terminal_ids':targets};
      });
      return jsonResponse(result,status:201);
    } catch (e) { return jsonResponse({'error':'Publishing failed. No changes committed: $e'},status:400); }
  });

  // Demo-mode sale recording. Never a BIR invoice; cannot reduce stock.
  // Server gets prices from published product_prices (client totals are not trusted).
  router.post('/sales/test', (Request request) async {
    final session=sessionFor(request);
    if (session==null || session.role!='cashier' || session.terminalId==null) {
      return jsonResponse({'error':'Cashier login required'},status:403);
    }
    Map<String,dynamic> body;
    try { body=Map<String,dynamic>.from(jsonDecode(await request.readAsString()) as Map); }
    catch (_) { return jsonResponse({'error':'Invalid JSON'},status:400); }
    if (body['items'] is! List || (body['items'] as List).isEmpty) {
      return jsonResponse({'error':'Add at least one item'},status:400);
    }
    final items=(body['items'] as List);
    if (items.length>100) return jsonResponse({'error':'Too many items'},status:400);
    final tendered=num.tryParse('${body['tendered']}');
    final discount=num.tryParse('${body['sale_discount_percent']??0}');
    final wholesale=body['wholesale']==true;
    if (tendered==null || !tendered.isFinite || tendered<0 ||
        discount==null || !discount.isFinite || discount<0 || discount>100) {
      return jsonResponse({'error':'Invalid payment or discount'},status:400);
    }
    // Prices rounded to cents for storage; this development mode intentionally
    // does not implement final fiscal rounding, VAT, or official discounts.
    double money(double v)=>double.parse(v.toStringAsFixed(2));
    try {
      final data=await connection.runTx((tx) async {
        final lines=<({int? id,String unit,String? description,int qty,double price,double total})>[];
        var subtotal=0.0;var count=0;
        for (final raw in items) {
          if (raw is! Map) throw StateError('Invalid cart line');
          final line=Map<String,dynamic>.from(raw);
          final barcode=(line['barcode']??'').toString();
          final qty=line['quantity'];
          final itemDiscount=num.tryParse('${line['discount_percent']??0}');
          if (qty is! int || qty<1 || qty>10000 ||
              itemDiscount==null || !itemDiscount.isFinite || itemDiscount<0 || itemDiscount>100) {
            throw StateError('Invalid item quantity or discount');
          }
          // Manual Grocery lines are development-only and have no stock product.
          // The cashier specifies the price; require a positive, finite peso amount.
          if (line['manual'] == true) {
            final desc=(line['description']??'').toString();
            final manualPrice=num.tryParse('${line['unit_price']}');
            if (desc!='Grocery' || barcode.isNotEmpty && !barcode.startsWith('MANUAL-') ||
                manualPrice==null || !manualPrice.isFinite || manualPrice<=0 || manualPrice>100000) {
              throw StateError('Invalid manual Grocery price');
            }
            final price=money(manualPrice.toDouble());
            final lineTotal=money(price*qty*(1-itemDiscount/100));
            subtotal+=lineTotal;count+=qty;
            lines.add((id:null,unit:'manual',description:'Grocery',qty:qty,price:price,total:lineTotal));
            continue;
          }
          if (barcode.isEmpty) throw StateError('Published product barcode required');
          final matched=await tx.execute(Sql.named('''SELECT p.id,b.unit,pp.selling_price
            FROM product_barcodes b
            JOIN products p ON p.id=b.product_id AND NOT p.is_archived
            JOIN product_prices pp ON pp.product_id=p.id AND pp.unit=b.unit
            WHERE b.barcode=@barcode AND EXISTS (
              SELECT 1 FROM product_drafts d
              JOIN publish_batch_drafts bd ON bd.draft_id=d.id
              JOIN publish_batch_targets bt ON bt.batch_id=bd.batch_id
              WHERE d.published_product_id=p.id AND bt.terminal_id=@counter)
          '''),parameters:{'barcode':barcode,'counter':session.terminalId});
          if (matched.isEmpty) throw StateError('Item $barcode is not published to this counter');
          final row=matched.first;
          final base=num.parse('${row[2]}').toDouble();
          final price=money(base*(wholesale?0.9:1.0));
          final lineTotal=money(price*qty*(1-itemDiscount/100));
          subtotal+=lineTotal;count+=qty;
          lines.add((id:row[0] as int,unit:row[1] as String,description:null,qty:qty,price:price,total:lineTotal));
        }
        final total=money(subtotal*(1-discount/100));
        if (tendered+0.00001<total) throw StateError('Insufficient cash tendered');
        final change=money(tendered-total);
        // Row-level serialized, rollback-safe receipt allocation per counter.
        // The global sale ID stays separate and is still used for API lookups.
        final seq = await tx.execute(Sql.named('''INSERT INTO dev_counter_receipt_sequences (terminal_id,next_number)
          VALUES (@counter,2)
          ON CONFLICT (terminal_id) DO UPDATE
            SET next_number=dev_counter_receipt_sequences.next_number+1
          RETURNING next_number-1'''),parameters:{'counter':session.terminalId});
        final receiptNo = (seq.first[0] as num).toInt();
        final sale=await tx.execute(Sql.named('''INSERT INTO dev_test_sales
          (terminal_id,cashier_user_id,receipt_no,total,tendered,change_due,item_count)
          VALUES (@counter,@cashier,@receipt_no,@total,@cash,@change,@count) RETURNING id'''),
          parameters:{'counter':session.terminalId,'cashier':session.userId,
            'receipt_no':receiptNo,'total':total,'cash':tendered,'change':change,'count':count});
        final saleId=sale.first[0] as int;
        for (final line in lines) {
          await tx.execute(Sql.named('''INSERT INTO dev_test_sale_lines
            (sale_id,product_id,description,unit,quantity,unit_price,line_total)
            VALUES (@sale,@product,@description,@unit,@qty,@price,@total)'''),parameters:{
            'sale':saleId,'product':line.id,'description':line.description,'unit':line.unit,
            'qty':line.qty,'price':line.price,'total':line.total});
        }
        await tx.execute(Sql.named('UPDATE terminals SET last_seen_at=now() WHERE id=@id'),
          parameters:{'id':session.terminalId});
        return {'id':saleId,'receipt_no':receiptNo,'terminal_id':session.terminalId,'is_test':true,'total':total,'tendered':tendered,
          'change_due':change,'item_count':count};
      });
      return jsonResponse(data,status:201);
    } catch (e) { return jsonResponse({'error':'Test sale not recorded: $e'},status:400); }
  });

  // Development-only cash counts. These do NOT close any fiscal day.
  // Expected cash is only the total of saved cash test-sales for this counter
  // on the Philippine-local date; opening float, cash-in/out, refunds and
  // other payment types are not modeled. An existing daily count is replaced
  // explicitly in the development ledger (not an audit-safe production rule).
  router.post('/cash/test-count', (Request request) async {
    final session = sessionFor(request);
    if (session == null || session.role != 'cashier' || session.terminalId == null) {
      return jsonResponse({'error':'Cashier login required'},status:403);
    }
    Map<String,dynamic> body;
    try {body=Map<String,dynamic>.from(jsonDecode(await request.readAsString()) as Map);}
    catch (_) {return jsonResponse({'error':'Invalid JSON'},status:400);}
    if (body['denominations'] is! Map) {
      return jsonResponse({'error':'Denomination counts required'},status:400);
    }
    const values = <String,int>{'1000.00':100000,'500.00':50000,'200.00':20000,
      '100.00':10000,'50.00':5000,'20.00':2000,'10.00':1000,'5.00':500,
      '1.00':100,'0.25':25};
    final entered=Map<String,dynamic>.from(body['denominations'] as Map);
    if (entered.keys.any((key)=>!values.containsKey(key))) {
      return jsonResponse({'error':'Unknown denomination'},status:400);
    }
    var cents=0;
    for (final key in values.keys) {
      final raw=entered[key]??0;
      if (raw is! int || raw<0 || raw>100000) {
        return jsonResponse({'error':'Invalid count for $key'},status:400);
      }
      cents += raw*values[key]!;
    }
    if (cents==0 || cents>100000000000) {
      return jsonResponse({'error':'Enter a nonzero cash count within the test limit'},status:400);
    }
    final result = await connection.runTx((tx) async {
      final sales=await tx.execute(Sql.named('''SELECT COALESCE(SUM(total),0)
        FROM dev_test_sales WHERE terminal_id=@counter
        AND (created_at AT TIME ZONE 'Asia/Manila')::date=(now() AT TIME ZONE 'Asia/Manila')::date'''),
        parameters:{'counter':session.terminalId});
      final expected = num.parse('${sales.first[0]}');
      final counted = cents/100;
      final variance = double.parse((counted-expected).toStringAsFixed(2));
      final saved=await tx.execute(Sql.named('''INSERT INTO dev_test_cash_counts
        (terminal_id,cashier_user_id,business_day,denominations,
         expected_cash,counted_cash,variance)
        VALUES (@counter,@cashier,(now() AT TIME ZONE 'Asia/Manila')::date,
          CAST(@denoms AS jsonb),@expected,@counted,@variance)
        ON CONFLICT(terminal_id,business_day) DO UPDATE SET
          cashier_user_id=EXCLUDED.cashier_user_id,
          denominations=EXCLUDED.denominations,
          expected_cash=EXCLUDED.expected_cash,
          counted_cash=EXCLUDED.counted_cash,
          variance=EXCLUDED.variance,
          updated_at=now() RETURNING id,business_day'''),parameters:{
          'counter':session.terminalId,'cashier':session.userId,
          'denoms':jsonEncode(entered),'expected':expected,
          'counted':counted,'variance':variance});
      return {'id':saved.first[0],'terminal_id':session.terminalId,
        'business_day':'${saved.first[1]}','expected_cash':expected,
        'counted_cash':counted,'variance':variance,'test_only':true};
    });
    return jsonResponse(result,status:201);
  });

  router.get('/cash/test-reconciliations', (Request request) async {
    if (sessionFor(request)?.role!='admin') {
      return jsonResponse({'error':'Admin required'},status:403);
    }
    final rows=await connection.execute('''SELECT c.id,c.terminal_id,c.business_day,
      c.expected_cash,c.counted_cash,c.variance,
      t.label,u.display_name
      FROM dev_test_cash_counts c
      JOIN terminals t ON t.id=c.terminal_id
      LEFT JOIN app_users u ON u.id=c.cashier_user_id
      ORDER BY c.business_day DESC,c.terminal_id''');
    return jsonResponse([for (final r in rows){
      'id':r[0],'terminal_id':r[1], 'business_day':'${r[2]}',
      'expected_cash':num.parse('${r[3]}'),
      'counted_cash':num.parse('${r[4]}'),
      'variance':num.parse('${r[5]}'),
      'counter_label':r[6], 'cashier_name':r[7],
    }]);
  });

  // Admin dashboard: test sales are kept separate from real/official reporting.
  router.get('/overview/test', (Request request) async {
    if (sessionFor(request)?.role!='admin') return jsonResponse({'error':'Admin required'},status:403);
    final totals=await connection.execute('''SELECT COALESCE(sum(total),0), count(*),
      COALESCE(sum(item_count),0) FROM dev_test_sales''');
    final counters=await connection.execute('''SELECT t.id,t.label,t.display_name,
      (t.last_seen_at IS NOT NULL AND t.last_seen_at >= now()-interval '5 minutes') AS live,
      COALESCE(sum(s.total),0) AS sales
      FROM terminals t LEFT JOIN dev_test_sales s ON s.terminal_id=t.id
      WHERE t.is_active=true
      GROUP BY t.id,t.label,t.display_name,t.last_seen_at ORDER BY t.id''');
    final daily=await connection.execute('''
      WITH days AS (
        SELECT generate_series(
          (now() AT TIME ZONE 'Asia/Manila')::date - 6,
          (now() AT TIME ZONE 'Asia/Manila')::date,
          interval '1 day')::date AS day
      ), sales AS (
        SELECT (created_at AT TIME ZONE 'Asia/Manila')::date AS day,
          sum(total) AS total FROM dev_test_sales GROUP BY 1
      )
      SELECT to_char(days.day,'Dy'),COALESCE(sales.total,0)
      FROM days LEFT JOIN sales ON sales.day=days.day ORDER BY days.day
    ''');
    final inventory=await connection.execute('''SELECT
      COALESCE(SUM(b.quantity_pieces * p.supplier_cost_per_piece),0),
      COUNT(*) FILTER (WHERE b.reorder_level > 0 AND b.quantity_pieces <= b.reorder_level)
      FROM dev_stock_balances b JOIN products p ON p.id=b.product_id AND NOT p.is_archived''');
    final r=totals.first;
    return jsonResponse({'gross_sales':num.parse('${r[0]}'),'transactions':r[1],
      'items_sold':r[2],'test_only':true,
      'inventory_value':num.parse('${inventory.first[0]}'),
      'low_stock':inventory.first[1],
      'daily_sales':daily.map((x)=>{'day':x[0].toString().trim(),
        'sales':num.parse('${x[1]}')}).toList(),
      'counters':counters.map((c)=>{
        'id':c[0],'label':c[1],'display_name':c[2],
        'live':c[3],'sales':num.parse('${c[4]}')}).toList()});
  });

  // DEVELOPMENT inventory and suppliers. Not fiscal accounting.
  router.get('/inventory', (Request request) async {
    if (sessionFor(request)?.role!='admin') return jsonResponse({'error':'Admin required'},status:403);
    final rows=await connection.execute('''SELECT p.id,p.description,p.pieces_per_case,
      COALESCE(b.quantity_pieces,0),COALESCE(b.reorder_level,0),
      p.supplier_cost_per_piece,s.name
      FROM products p LEFT JOIN dev_stock_balances b ON b.product_id=p.id
      LEFT JOIN suppliers s ON s.id=p.supplier_id
      WHERE NOT p.is_archived ORDER BY p.description''');
    return jsonResponse(rows.map((r)=>{
      'product_id':r[0], 'description':r[1], 'pieces_per_case':r[2],
      'quantity_pieces':r[3], 'reorder_level':r[4],
      'cost_per_piece':num.parse('${r[5]}'),'supplier':r[6],
    }).toList());
  });

  router.post('/inventory/receive', (Request request) async {
    if (sessionFor(request)?.role!='admin') return jsonResponse({'error':'Admin required'},status:403);
    Map<String,dynamic> body;
    try {body=Map<String,dynamic>.from(jsonDecode(await request.readAsString()) as Map);}
    catch(_){return jsonResponse({'error':'Invalid JSON'},status:400);}
    final product=body['product_id'];
    final pieces=body['pieces'];
    final cases=body['cases'];
    final reorder=body['reorder_level'];
    if(product is! int || product<1 || pieces is! int || cases is! int ||
       pieces<0 || cases<0 || (pieces==0 && cases==0) || pieces>1000000 || cases>100000 ||
       (reorder!=null && (reorder is! int || reorder<0 || reorder>1000000))) {
      return jsonResponse({'error':'Select a product and valid whole-number quantities'},status:400);
    }
    try {
      final output=await connection.runTx((tx) async {
        final check=await tx.execute(Sql.named(
          'SELECT pieces_per_case FROM products WHERE id=@id AND NOT is_archived FOR UPDATE'),
          parameters:{'id':product});
        if(check.isEmpty) throw StateError('Published product not found');
        final perCase=check.first[0] as int;
        final added=pieces+cases*perCase;
        // PostgreSQL cannot always infer the type of an untyped NULL bound to
        // COALESCE. Use two explicit, integer-only statements instead.
        if (reorder == null) {
          await tx.execute(Sql.named('''INSERT INTO dev_stock_balances
            (product_id,quantity_pieces,reorder_level)
            VALUES (@id,@added,0)
            ON CONFLICT(product_id) DO UPDATE SET
              quantity_pieces=dev_stock_balances.quantity_pieces+EXCLUDED.quantity_pieces,
              updated_at=now()'''),
            parameters:{'id':product,'added':added});
        } else {
          await tx.execute(Sql.named('''INSERT INTO dev_stock_balances
            (product_id,quantity_pieces,reorder_level)
            VALUES (@id,@added,@reorder)
            ON CONFLICT(product_id) DO UPDATE SET
              quantity_pieces=dev_stock_balances.quantity_pieces+EXCLUDED.quantity_pieces,
              reorder_level=EXCLUDED.reorder_level,
              updated_at=now()'''),
            parameters:{'id':product,'added':added,'reorder':reorder});
        }
        await tx.execute(Sql.named('''INSERT INTO dev_stock_movements
          (product_id,quantity_pieces,movement_type,created_by)
          VALUES (@id,@added,'receive',@user)'''),
          parameters:{'id':product,'added':added,'user':sessionFor(request)!.userId});
        final balance=await tx.execute(Sql.named(
          'SELECT quantity_pieces FROM dev_stock_balances WHERE product_id=@id'),
          parameters:{'id':product});
        return {'product_id':product,'received_pieces':added,'quantity_pieces':balance.first[0]};
      });
      return jsonResponse(output,status:201);
    } catch(e) {return jsonResponse({'error':'Stock not received: $e'},status:400);}
  });

  router.get('/suppliers', (Request request) async {
    if (sessionFor(request)?.role!='admin') return jsonResponse({'error':'Admin required'},status:403);
    final rows=await connection.execute('''SELECT s.id,s.name,s.phone,
      (SELECT count(*) FROM products p WHERE p.supplier_id=s.id AND NOT p.is_archived)
      FROM suppliers s ORDER BY lower(s.name)''');
    return jsonResponse(rows.map((r)=>{'id':r[0],'name':r[1],
      'phone':r[2],'product_count':r[3]}).toList());
  });
  router.post('/suppliers', (Request request) async {
    if (sessionFor(request)?.role!='admin') return jsonResponse({'error':'Admin required'},status:403);
    Map<String,dynamic> body;
    try {body=Map<String,dynamic>.from(jsonDecode(await request.readAsString()) as Map);}
    catch(_) {return jsonResponse({'error':'Invalid JSON'},status:400);}
    final name=(body['name']??'').toString().trim();
    final phone=(body['phone']??'').toString().trim();
    if(name.isEmpty || name.length>120 || phone.length>40) {
      return jsonResponse({'error':'Supplier name required (up to 120 characters)'},status:400);
    }
    try {
      final duplicate = await connection.execute(Sql.named('''
        SELECT id FROM suppliers WHERE lower(trim(name))=lower(@name) LIMIT 1
      '''), parameters:{'name':name});
      if (duplicate.isNotEmpty) {
        return jsonResponse({'error':'A supplier with this name already exists.'},status:409);
      }
      final rows=await connection.execute(Sql.named('''INSERT INTO suppliers(name,phone)
        VALUES (@name,@phone) RETURNING id'''),
        parameters:{'name':name,'phone':phone});
      return jsonResponse({'id':rows.first[0],'name':name,'phone':phone},status:201);
    } catch(e) {
      // Handle concurrent insertions violating the unique constraint too.
      if ('$e'.contains('23505') || '$e'.contains('duplicate key')) {
        return jsonResponse({'error':'Supplier already exists.'},status:409);
      }
      return jsonResponse({'error':'Supplier could not be saved: $e'},status:400);
    }
  });

  router.post('/counter/ping', (Request request) async {
    final sess=sessionFor(request);
    if (sess==null || sess.role!='cashier') return jsonResponse({'error':'Cashier login required'},status:403);
    await connection.execute(Sql.named('UPDATE terminals SET last_seen_at=now() WHERE id=@id'),parameters:{'id':sess.terminalId});
    return jsonResponse({'ok':true});
  });
  // Development-only online verification for cart void approval.
  // Do not accept a hard-coded shared demo password as authorization.
  router.post('/void/authorize', (Request request) async {
    final session = sessionFor(request);
    if (session == null) return jsonResponse({'error':'Login required'}, status:401);
    Map<String,dynamic> body;
    try { body = Map<String,dynamic>.from(jsonDecode(await request.readAsString()) as Map); }
    catch (_) { return jsonResponse({'error':'Invalid JSON'}, status:400); }
    final username = (body['username'] ?? '').toString().trim().toLowerCase();
    final password = (body['password'] ?? '').toString();
    final result = await connection.execute(Sql.named('''
      SELECT password_salt, password_hash FROM app_users
      WHERE username = @username AND role = 'admin' AND active = true
    '''), parameters: {'username':username});
    if (result.isEmpty) return jsonResponse({'authorized': false}, status:403);
    final admin = result.first.toColumnMap();
    final allowed = safeEqual(
      passwordHash(password, admin['password_salt'] as String),
      admin['password_hash'] as String,
    );
    return jsonResponse({'authorized': allowed}, status: allowed ? 200 : 403);
  });

  router.post('/logout', (Request request) {
    final auth = request.headers['authorization'] ?? '';
    if (auth.startsWith('Bearer ')) sessions.remove(auth.substring(7));
    return jsonResponse({'ok':true});
  });
  // Return each counter with its single linked cashier login for the Admin editor.
  router.get('/terminals', (Request request) async {
    if (sessionFor(request)?.role != 'admin') {
      return jsonResponse({'error':'Admin access required'},status:403);
    }
    final rows = await connection.execute('''SELECT t.id, t.label, t.display_name, t.is_active,
          u.id AS cashier_user_id, u.username AS cashier_username,
          u.display_name AS cashier_display_name
       FROM terminals t
       LEFT JOIN LATERAL (
         SELECT id, username, display_name
         FROM app_users
         WHERE terminal_id=t.id AND role='cashier' AND active=true
         ORDER BY id LIMIT 1
       ) u ON true
       ORDER BY t.id''');
    return jsonResponse(rows.map((r)=>r.toColumnMap()).toList());
  });
  router.post('/terminals', (Request request) async {
    if (sessionFor(request)?.role != 'admin') return jsonResponse({'error':'Admin access required'},status:403);
    Map<String,dynamic> body;
    try { body=Map<String,dynamic>.from(jsonDecode(await request.readAsString()) as Map); }
    catch (_) { return jsonResponse({'error':'Invalid JSON'},status:400); }
    final name=(body['display_name']??'').toString().trim();
    if (name.length > 60) return jsonResponse({'error':'Name must be 60 characters or less'},status:400);
    // Assign the next available counter number while preserving historical IDs.
    // Transactional lock avoids two simultaneous Admin requests choosing the same ID.
    try {
      final row=await connection.runTx((tx) async {
        await tx.execute('SELECT pg_advisory_xact_lock(719401)');
        final maxRows=await tx.execute('SELECT COALESCE(MAX(id),0) FROM terminals');
        final next=(maxRows.first[0] as int)+1;
        if (next > 999) throw StateError('Maximum of 999 counter IDs reached');
        final label='Counter ${next.toString().padLeft(2,'0')}';
        final rows=await tx.execute(Sql.named('INSERT INTO terminals (id,label,display_name,is_active) VALUES (@id,@label,@name,true) RETURNING id,label,display_name,is_active'),parameters:{'id':next,'label':label,'name':name.isEmpty?label:name});
        return rows.first.toColumnMap();
      });
      return jsonResponse(row,status:201);
    } catch (e) {
      return jsonResponse({'error':'Could not add counter: $e'},status:400);
    }
  });
  // One Edit action updates the counter's name and its cashier login together.
  // Password may be blank when editing an existing login (keep current password).
  router.patch('/terminals/<id>', (Request request, String id) async {
    if (sessionFor(request)?.role != 'admin') {
      return jsonResponse({'error':'Admin access required'},status:403);
    }
    final terminalId = int.tryParse(id);
    if (terminalId == null || terminalId < 1 || terminalId > 999) {
      return jsonResponse({'error':'Invalid counter'},status:400);
    }
    Map<String,dynamic> body;
    try {
      body = Map<String,dynamic>.from(jsonDecode(await request.readAsString()) as Map);
    } catch (_) {
      return jsonResponse({'error':'Invalid JSON'},status:400);
    }
    final displayName = (body['display_name'] ?? '').toString().trim();
    final username = (body['username'] ?? '').toString().trim().toLowerCase();
    final newPassword = (body['password'] ?? '').toString();
    if (displayName.isEmpty || displayName.length > 60 ||
        !RegExp(r'^[a-z0-9_]{1,32}$').hasMatch(username)) {
      return jsonResponse({'error':'Enter a name (1-60 characters) and username (1-32 letters, numbers, underscores).'},status:400);
    }
    try {
      final result = await connection.runTx((tx) async {
        final t = await tx.execute(Sql.named(
          'SELECT id FROM terminals WHERE id=@id AND is_active=true FOR UPDATE'),
          parameters:{'id':terminalId});
        if (t.isEmpty) throw StateError('Active counter not found');
        final account = await tx.execute(Sql.named(
          "SELECT id FROM app_users WHERE terminal_id=@id AND role='cashier' AND active=true ORDER BY id FOR UPDATE"),
          parameters:{'id':terminalId});
        if (account.length > 1) {
          throw StateError('More than one active cashier uses this counter; resolve duplicate assignments before editing.');
        }
        if (account.isEmpty && newPassword.isEmpty) {
          throw StateError('Enter a password when creating this counter login.');
        }
        await tx.execute(Sql.named(
          'UPDATE terminals SET display_name=@name WHERE id=@id'),
          parameters:{'name':displayName,'id':terminalId});
        if (account.isEmpty) {
          final salt = newToken();
          await tx.execute(Sql.named('''INSERT INTO app_users
              (username,display_name,password_salt,password_hash,role,terminal_id)
              VALUES (@username,@name,@salt,@hash,'cashier',@counter)'''),
            parameters:{'username':username,'name':displayName,'salt':salt,
              'hash':passwordHash(newPassword,salt),'counter':terminalId});
        } else {
          final userId = account.first[0] as int;
          if (newPassword.isEmpty) {
            await tx.execute(Sql.named('''UPDATE app_users
              SET username=@username,display_name=@name WHERE id=@id'''),
              parameters:{'username':username,'name':displayName,'id':userId});
          } else {
            final salt = newToken();
            await tx.execute(Sql.named('''UPDATE app_users
              SET username=@username,display_name=@name,
                  password_salt=@salt,password_hash=@hash WHERE id=@id'''),
              parameters:{'username':username,'name':displayName,
                'salt':salt,'hash':passwordHash(newPassword,salt),'id':userId});
          }
        }
        return {'id':terminalId,'display_name':displayName,'username':username};
      });
      // Expire older counter sessions so updated credentials take effect.
      sessions.removeWhere((_,s)=>s.role=='cashier' && s.terminalId==terminalId);
      return jsonResponse(result);
    } catch (e) {
      return jsonResponse({'error':'Could not save counter: $e'},status:400);
    }
  });
  // 'Delete' means deactivate: keep the row for invoices and historical records.
  router.delete('/terminals/<id>', (Request request, String id) async {
    if (sessionFor(request)?.role != 'admin') return jsonResponse({'error':'Admin access required'},status:403);
    final terminalId = int.tryParse(id);
    if (terminalId == null) return jsonResponse({'error':'Invalid counter'},status:400);
    final result = await connection.execute(Sql.named(
      'UPDATE terminals SET is_active=false WHERE id=@id AND is_active=true RETURNING id'),
      parameters:{'id':terminalId});
    if (result.isEmpty) return jsonResponse({'error':'Active counter not found'},status:404);
    sessions.removeWhere((_,session)=>session.terminalId==terminalId);
    return jsonResponse({'id':terminalId,'is_active':false});
  });
  router.post('/terminals/<id>/restore', (Request request, String id) async {
    if (sessionFor(request)?.role != 'admin') return jsonResponse({'error':'Admin access required'},status:403);
    final terminalId = int.tryParse(id);
    if (terminalId == null) return jsonResponse({'error':'Invalid counter'},status:400);
    final result = await connection.execute(Sql.named(
      'UPDATE terminals SET is_active=true WHERE id=@id AND is_active=false RETURNING id'),
      parameters:{'id':terminalId});
    if (result.isEmpty) return jsonResponse({'error':'Deactivated counter not found'},status:404);
    return jsonResponse({'id':terminalId,'is_active':true});
  });
  router.get('/users', (Request request) async {
    if (sessionFor(request)?.role != 'admin') return jsonResponse({'error':'Admin access required'},status:403);
    final rows = await connection.execute("""SELECT id, username, display_name, role, terminal_id, active
       FROM app_users ORDER BY id""");
    return jsonResponse(rows.map((r)=>r.toColumnMap()).toList());
  });
  router.post('/users', (Request request) async {
    if (sessionFor(request)?.role != 'admin') return jsonResponse({'error':'Admin access required'},status:403);
    Map<String,dynamic> body;
    try { body = Map<String,dynamic>.from(jsonDecode(await request.readAsString()) as Map); }
    catch (_) { return jsonResponse({'error':'Invalid JSON'},status:400); }
    final username = (body['username'] ?? '').toString().trim().toLowerCase();
    final password = (body['password'] ?? '').toString();
    final displayName = (body['display_name'] ?? '').toString().trim();
    final terminalId = body['terminal_id'];
    if (!RegExp(r'^[a-z0-9_]{1,32}$').hasMatch(username) || password.isEmpty ||
        displayName.isEmpty || displayName.length > 60 ||
        terminalId is! int || terminalId < 1 || terminalId > 999) {
      return jsonResponse({'error':'Username: 1–32 letters/numbers/underscores. Cashier name: 1–60 characters. Enter a password and choose an active counter.'},status:400);
    }
    final activeCounter = await connection.execute(Sql.named(
      'SELECT is_active FROM terminals WHERE id=@id'),parameters:{'id':terminalId});
    if (activeCounter.isEmpty || activeCounter.first[0] != true) {
      return jsonResponse({'error':'Select an active counter'},status:400);
    }
    final salt = newToken();
    final hash = passwordHash(password,salt);
    try {
      final rows = await connection.execute(Sql.named("""INSERT INTO app_users
        (username,display_name,password_salt,password_hash,role,terminal_id)
        VALUES (@username,@display_name,@salt,@hash,'cashier',@terminal_id)
        RETURNING id"""),parameters:{'username':username,'display_name':displayName,'salt':salt,'hash':hash,'terminal_id':terminalId});
      return jsonResponse({'id':rows.first[0],'username':username,'display_name':displayName,'terminal_id':terminalId},status:201);
    } catch (_) { return jsonResponse({'error':'Username already in use or invalid account'},status:409); }
  });

  router.get('/health', (Request request) async {
    final check = await connection.execute('SELECT current_database()');
    return jsonResponse({'ok': true, 'database': check.first[0]});
  });

  router.get('/products', (Request request) async {
    final viewer = sessionFor(request);
    final counter = viewer?.role=='cashier' ? viewer!.terminalId : null;
    final result = await connection.execute(Sql.named('''
      SELECT p.id, p.description, p.category, p.pieces_per_case,
             p.sell_piece, p.sell_case, p.supplier_cost_per_piece,
             s.name AS supplier,
             (SELECT barcode FROM product_barcodes b
               WHERE b.product_id = p.id AND b.unit = 'piece' LIMIT 1) AS piece_barcode,
             (SELECT barcode FROM product_barcodes b
               WHERE b.product_id = p.id AND b.unit = 'case' LIMIT 1) AS case_barcode,
             (SELECT selling_price FROM product_prices pp
               WHERE pp.product_id = p.id AND pp.unit = 'piece') AS piece_price,
             (SELECT selling_price FROM product_prices pp
               WHERE pp.product_id = p.id AND pp.unit = 'case') AS case_price
      FROM products p
      LEFT JOIN suppliers s ON s.id = p.supplier_id
      WHERE NOT p.is_archived
        AND (COALESCE(CAST(@counter AS integer),0)=0 OR EXISTS (
          SELECT 1 FROM product_drafts d
          JOIN publish_batch_drafts bd ON bd.draft_id = d.id
          JOIN publish_batch_targets bt ON bt.batch_id = bd.batch_id
          WHERE d.published_product_id = p.id AND bt.terminal_id = @counter))
      ORDER BY p.id
    '''),parameters:{'counter':counter});
    return jsonResponse(result.map((r) {
      final m = r.toColumnMap();
      // JSON encoder does not serialize the driver's Decimal instances.
      return m.map((key, value) => MapEntry(key, value is num || value == null || value is bool
          ? value : value.toString()));
    }).toList());
  });

  router.get('/drafts', (Request request) async {
    final result = await connection.execute('''
      SELECT id, product_id, action, proposed_data, status, created_at
      FROM product_drafts WHERE status = 'pending' ORDER BY created_at DESC, id DESC
    ''');
    return jsonResponse(result.map((r) {
      final m = r.toColumnMap();
      return {
        'id': m['id'],
        'product_id': m['product_id'],
        'action': m['action'],
        'proposed_data': m['proposed_data'] is String
            ? jsonDecode(m['proposed_data'] as String)
            : m['proposed_data'],
        'status': m['status'],
        'created_at': m['created_at'].toString(),
      };
    }).toList());
  });

  // Local development endpoints ONLY. Add authorization before network use.
  router.post('/drafts', (Request request) async {
    final body = await readDraftBody(request);
    if (body is Response) return body;
    final payload = body as Map<String, dynamic>;
    final result = await connection.execute(
      Sql.named('''INSERT INTO product_drafts (action, proposed_data)
          VALUES ('create', CAST(@payload AS jsonb)) RETURNING id'''),
      parameters: {'payload': jsonEncode(payload)},
    );
    return jsonResponse({'id': result.first[0], 'status': 'pending'}, status: 201);
  });

  router.patch('/drafts/<id>', (Request request, String id) async {
    final draftId = int.tryParse(id);
    if (draftId == null || draftId < 1) {
      return jsonResponse({'error': 'Invalid draft ID'}, status: 400);
    }
    final body = await readDraftBody(request);
    if (body is Response) return body;
    final result = await connection.execute(
      Sql.named('''UPDATE product_drafts
          SET proposed_data = CAST(@payload AS jsonb)
          WHERE id = @id AND status = 'pending' AND action IN ('create','update')
          RETURNING id'''),
      parameters: {'payload': jsonEncode(body), 'id': draftId},
    );
    if (result.isEmpty) {
      return jsonResponse({'error': 'Pending creation draft not found'}, status: 404);
    }
    return jsonResponse({'id': result.first[0], 'status': 'pending'});
  });

  router.delete('/drafts/<id>', (Request request, String id) async {
    final draftId = int.tryParse(id);
    if (draftId == null || draftId < 1) {
      return jsonResponse({'error': 'Invalid draft ID'}, status: 400);
    }
    final result = await connection.execute(
      Sql.named('''UPDATE product_drafts SET status = 'discarded'
          WHERE id = @id AND status = 'pending' AND action IN ('create','update')
          RETURNING id'''),
      parameters: {'id': draftId},
    );
    if (result.isEmpty) {
      return jsonResponse({'error': 'Pending creation draft not found'}, status: 404);
    }
    return jsonResponse({'id': result.first[0], 'status': 'discarded'});
  });

  // Enforce authentication and authorization on the server, not only in Flutter.
  Future<Response> protectedHandler(Request request) async {
    final path = request.url.path;
    if (path == 'health' || path == 'login') return router.call(request);
    final session = sessionFor(request);
    if (session == null) return jsonResponse({'error':'Login required'}, status:401);
    if (path == 'logout') return router.call(request);
    if (session.role == 'cashier') {
      final status = await connection.execute(Sql.named(
        'SELECT is_active FROM terminals WHERE id=@id'),
        parameters:{'id':session.terminalId});
      if (status.isEmpty || status.first[0] != true) {
        return jsonResponse({'error':'Counter deactivated'},status:403);
      }
    }
    final adminOnly = path.startsWith('drafts') || path == 'users' || path.startsWith('admin/') ||
        path.startsWith('terminals/') || path.startsWith('inventory') || path.startsWith('suppliers') || path == 'publish' || (path.startsWith('products/') && path.endsWith('/draft'));
    if (adminOnly && session.role != 'admin') return jsonResponse({'error':'Admin only'},status:403);
    return router.call(request);
  }
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(protectedHandler);
  final server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 8080);
  stdout.writeln('IONYK development API on http://${server.address.address}:${server.port}');
  stdout.writeln('Local-only authenticated development API. Do NOT expose to LAN.');

  // Graceful shutdown: closing the connection is left to process shutdown in this starter.
}

Response jsonResponse(Object? payload, {int status = 200}) => Response(
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
  body: jsonEncode(payload),
);

// Validate and normalize user input before any database write.
Future<Object> readDraftBody(Request request) async {
  Object? decoded;
  try {
    decoded = jsonDecode(await request.readAsString());
  } catch (_) {
    return jsonResponse({'error': 'Invalid JSON'}, status: 400);
  }
  if (decoded is! Map<String, dynamic>) {
    return jsonResponse({'error': 'Expected a JSON object'}, status: 400);
  }
  final description = decoded['description'];
  final barcode = decoded['piece_barcode'];
  final cost = num.tryParse('${decoded['supplier_cost_per_piece']}');
  final price = num.tryParse('${decoded['piece_price']}');
  final casePrice = decoded['case_price'] == null
      ? null : num.tryParse('${decoded['case_price']}');
  final pieces = decoded['pieces_per_case'] == null
      ? 1 : int.tryParse('${decoded['pieces_per_case']}');
  final units = decoded['selling_units'] ?? 'piece';
  final caseBarcode = decoded['case_barcode'] ?? '';
  if (description is! String || description.trim().isEmpty ||
      description.trim().length > 300 ||
      barcode is! String || barcode.trim().isEmpty || barcode.trim().length > 100 ||
      caseBarcode is! String || caseBarcode.length > 100 ||
      (caseBarcode.isNotEmpty && caseBarcode.trim() == barcode.trim()) ||
      cost == null || !cost.isFinite || cost < 0 ||
      price == null || !price.isFinite || price < 0 ||
      (casePrice != null && (!casePrice.isFinite || casePrice < 0)) ||
      pieces == null || pieces < 1 || pieces > 100000 ||
      !['piece', 'case', 'both'].contains(units) ||
      (units != 'piece' && (pieces < 2 || casePrice == null))) {
    return jsonResponse({'error': 'Invalid product fields, prices, units or barcodes'}, status: 400);
  }
  if (decoded['category'] != null && decoded['category'] is! String ||
      decoded['supplier'] != null && decoded['supplier'] is! String) {
    return jsonResponse({'error': 'Category and supplier must be text'}, status: 400);
  }
  return <String, dynamic>{
    'description': description.trim(),
    'piece_barcode': barcode.trim(),
    'supplier_cost_per_piece': cost,
    'piece_price': price,
    'case_price': casePrice ?? price * pieces,
    'case_barcode': caseBarcode.trim(),
    'pieces_per_case': pieces,
    'selling_units': units,
    'category': (decoded['category'] as String? ?? '').trim(),
    'supplier': (decoded['supplier'] as String? ?? '').trim(),
  };
}

// PBKDF2-HMAC-SHA256 with unique random salts. Passwords are never stored as plaintext.
String passwordHash(String password, String salt) {
  final key = utf8.encode(password);
  final saltBytes = base64Url.decode(base64Url.normalize(salt));
  final block = <int>[...saltBytes,0,0,0,1];
  final hmac = crypt.Hmac(crypt.sha256,key);
  var u = hmac.convert(block).bytes;
  final output = List<int>.from(u);
  for (var i=1;i<120000;i++) {
    u = hmac.convert(u).bytes;
    for (var j=0;j<output.length;j++) { output[j] ^= u[j]; }
  }
  return base64UrlEncode(output);
}
bool safeEqual(String a, String b) {
  final x=utf8.encode(a), y=utf8.encode(b);
  var difference=x.length^y.length;
  for (var i=0;i<x.length && i<y.length;i++) { difference |= x[i]^y[i]; }
  return difference==0;
}
