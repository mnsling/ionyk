import 'dart:convert';
import 'dart:io';

/// Windows development only. Use a configured server host once the API is
/// authenticated and deployed on the store LAN.
class IonykApi {
  const IonykApi({this.baseUrl = 'http://127.0.0.1:8080'});
  final String baseUrl;
  static String? sessionToken;
  static String? currentUsername;
  static String? currentDisplayName;
  static int? currentTerminalId;

  Future<dynamic> _request(String method, String path, [Object? body]) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      if (sessionToken != null) request.headers.set('authorization', 'Bearer $sessionToken');
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      final data = jsonDecode(text);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('API ${response.statusCode}: $data');
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String,dynamic>> login(String username,String password) async {
    final result = Map<String,dynamic>.from(await _request('POST','/login',
      {'username':username,'password':password}));
    sessionToken=result['token'] as String;
    currentUsername=result['username'] as String;
    currentDisplayName=(result['display_name'] as String?) ?? currentUsername;
    currentTerminalId=result['terminal_id'] as int?;
    return result;
  }
  Future<void> logout() async {
    try { if (sessionToken != null) await _request('POST','/logout'); }
    finally { sessionToken=null;currentUsername=null;currentDisplayName=null;currentTerminalId=null; }
  }
  Future<List<Map<String,dynamic>>> terminals() async =>
    (await _request('GET','/terminals') as List)
      .map((item)=>Map<String,dynamic>.from(item as Map)).toList();
  Future<Map<String,dynamic>> createCounter(String name) async =>
    Map<String,dynamic>.from(await _request('POST','/terminals', {'display_name':name}));
  Future<Map<String,dynamic>> updateCounterLogin(
      int id, String displayName, String username, String password) async =>
    Map<String,dynamic>.from(await _request('PATCH','/terminals/$id', {
      'display_name':displayName,
      'username':username,
      'password':password,
    }));
  Future<void> deactivateCounter(int id) async =>
    _request('DELETE','/terminals/$id').then((_) {});
  Future<void> restoreCounter(int id) async =>
    _request('POST','/terminals/$id/restore').then((_) {});
  Future<List<Map<String,dynamic>>> users() async =>
    (await _request('GET','/users') as List)
      .map((item)=>Map<String,dynamic>.from(item as Map)).toList();
  Future<Map<String,dynamic>> addCashier(String username,String password,int counter,String displayName) async =>
    Map<String,dynamic>.from(await _request('POST','/users',
      {'username':username,'password':password,'terminal_id':counter,'display_name':displayName}));

  /// Verify an Admin account before a cashier can void selected cart lines.
  /// Does not perform the void or create an audit record; cart is local-only.
  Future<bool> authorizeVoid(String username, String password) async {
    final response = Map<String, dynamic>.from(await _request('POST', '/void/authorize', {
      'username': username.trim(), 'password': password,
    }));
    return response['authorized'] == true;
  }


  Future<Map<String,dynamic>> changeAdminCredentials(String currentPassword,
      String newUsername,String newPassword) async => Map<String,dynamic>.from(
      await _request('POST','/admin/change-credentials',{
        'current_password':currentPassword,'new_username':newUsername,'new_password':newPassword}));

  Future<Map<String,dynamic>> publishDrafts(List<int> draftIds,List<int> terminalIds) async =>
      Map<String,dynamic>.from(await _request('POST','/publish',{
        'draft_ids':draftIds,'terminal_ids':terminalIds}));

  Future<Map<String,dynamic>> recordTestSale(Map<String,dynamic> sale) async =>
    Map<String,dynamic>.from(await _request('POST','/sales/test',sale));

  /// Saved development transactions; not official tax invoices.
  Future<List<Map<String,dynamic>>> testTransactions() async =>
      (await _request('GET','/sales/test') as List)
          .map((e)=>Map<String,dynamic>.from(e as Map)).toList();

  Future<Map<String,dynamic>> testReceipt(int id) async =>
      Map<String,dynamic>.from(await _request('GET','/sales/test/$id'));

  /// Stage an update to a published product for approval/publishing.
  Future<Map<String,dynamic>> createPublishedEditDraft(int productId, Map<String,dynamic> body) async =>
      Map<String,dynamic>.from(await _request('POST','/products/$productId/draft',body));

  Future<List<Map<String,dynamic>>> inventory() async =>
      (await _request('GET','/inventory') as List)
          .map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  Future<Map<String,dynamic>> receiveStock(int productId,int pieces,int cases,{int? reorderLevel}) async =>
      Map<String,dynamic>.from(await _request('POST','/inventory/receive',{
        'product_id':productId,'pieces':pieces,'cases':cases,'reorder_level':reorderLevel,
      }));
  Future<List<Map<String,dynamic>>> suppliers() async =>
      (await _request('GET','/suppliers') as List)
          .map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  Future<Map<String,dynamic>> addSupplier(String name,String phone) async =>
      Map<String,dynamic>.from(await _request('POST','/suppliers',{
        'name':name,'phone':phone,
      }));

  /// Development cashier session and opening drawer float.
  Future<Map<String,dynamic>> cashSession() async =>
      Map<String,dynamic>.from(await _request('GET','/cash/session'));
  Future<Map<String,dynamic>> startCashSession(double opening) async =>
      Map<String,dynamic>.from(await _request('POST','/cash/session/start',
        {'opening_cash':opening}));
  Future<Map<String,dynamic>> closeCashSession() async =>
      Map<String,dynamic>.from(await _request('POST','/cash/session/close',{}));
  Future<List<Map<String,dynamic>>> cashSessionHistory() async =>
      (await _request('GET','/cash/session/history') as List)
        .map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  Future<Map<String,dynamic>> receiptSettings() async =>
      Map<String,dynamic>.from(await _request('GET','/receipt/settings'));
  Future<void> saveReceiptSettings(Map<String,String> data) async {
    await _request('PUT','/receipt/settings',data);
  }

  /// DEVELOPMENT cash count: only a signed-in cashier can save their counter.
  /// The backend calculates expected money from test cash receipts, not Flutter.
  Future<Map<String,dynamic>> saveTestCashCount(Map<String,int> denominations) async =>
      Map<String,dynamic>.from(await _request('POST','/cash/test-count',
        {'denominations': denominations}));

  /// Admin review of development cash counts, NOT a fiscal Z-reading.
  Future<List<Map<String,dynamic>>> testCashReconciliations() async =>
      (await _request('GET','/cash/test-reconciliations') as List)
          .map((e)=>Map<String,dynamic>.from(e as Map)).toList();

  Future<Map<String,dynamic>> testOverview() async =>
    Map<String,dynamic>.from(await _request('GET','/overview/test'));

  Future<void> pingCounter() async => _request('POST','/counter/ping').then((_) {});

  Future<Map<String, dynamic>> health() async =>
      Map<String, dynamic>.from(await _request('GET', '/health'));

  Future<List<Map<String, dynamic>>> publishedProducts() async =>
      (await _request('GET', '/products') as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();

  Future<List<Map<String, dynamic>>> pendingDrafts() async =>
      (await _request('GET', '/drafts') as List)
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();

  Future<Map<String, dynamic>> createProductDraft(Map<String, dynamic> draft) async =>
      Map<String, dynamic>.from(await _request('POST', '/drafts', draft));

  Future<Map<String, dynamic>> updateProductDraft(int id, Map<String, dynamic> draft) async =>
      Map<String, dynamic>.from(await _request('PATCH', '/drafts/$id', draft));

  Future<Map<String, dynamic>> discardProductDraft(int id) async =>
      Map<String, dynamic>.from(await _request('DELETE', '/drafts/$id'));
}
