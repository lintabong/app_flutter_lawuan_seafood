import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class SupabaseService {

  static String? get currentUserId => supabase.auth.currentUser?.id;

  static Future<List<dynamic>> getCustomers() async {
    final response = await supabase
        .from('customers')
        .select('id, name, phone, address, latitude, longitude')
        .order('name');
    return response;
  }

  static Future<List<dynamic>> getProducts() async {
    final response = await supabase
        .from('products')
        .select('*, product_variants(id, name, unit, buy_price, sell_price)')
        .eq('is_active', true)
        .order('name');
    return response;
  }

  static Future<Map<String, dynamic>> createOrder({
    required int customerId,
    required String status,
    required int cashId,
    required List<Map<String, dynamic>> items,
    double deliveryPrice = 0,
    String deliveryType = 'pickup',
    DateTime? orderDate,
  }) async {
    // Convert to UTC/GMT — falls back to now() in the RPC if null
    final String? orderDateUtc = orderDate != null
        ? orderDate.toUtc().toIso8601String()
        : null;

    final response = await supabase.rpc(
      'apply_order',
      params: {
        'p_customer_id': customerId,
        'p_created_by': currentUserId,
        'p_status': status,
        'p_cash_id': cashId,
        'p_items': items,
        'p_delivery_price': deliveryPrice,
        'p_delivery_type': deliveryType,
        if (orderDateUtc != null) 'p_order_date': orderDateUtc,
      },
    );

    return response.first;
  }

  static Future<List<dynamic>> getOrders({
    int page = 1,
    int pageSize = 10,
    DateTime? date,
    String? status,
  }) async {
    final int from = (page - 1) * pageSize;
    final int to = from + pageSize - 1;

    var query = supabase
        .from('orders')
        .select('*, customers(id, name, phone)');

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    if (date != null) {
      final start = DateTime(date.year, date.month, date.day, 0, 0, 0).toUtc();
      final end   = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc();
      query = query
          .gte('order_date', start.toIso8601String())
          .lte('order_date', end.toIso8601String());
    }

    final response = await query
        .order('order_date', ascending: false)
        .range(from, to);

    return response;
  }

  static Future<Map<String, dynamic>> getOrderDetail(int orderId) async {
    final response = await supabase
        .from('orders')
        .select('''
          *,
          customers(id, name, phone, address, latitude, longitude),
          order_items(
            id,
            quantity,
            buy_price,
            sell_price,
            is_prepared,
            products(id, name, unit),
            product_variants(id, name, unit)
          )
        ''')
        .eq('id', orderId)
        .single();

    return response;
  }

  static Future<void> toggleItemPrepared(int itemId, bool value) async {
    await supabase
        .from('order_items')
        .update({'is_prepared': value})
        .eq('id', itemId);
  }

  // ── Order status via RPC ──────────────────────────────────
  static Future<Map<String, dynamic>> updateOrderStatusRpc({
    required int orderId,
    required String newStatus,
    int cashId = 1,
  }) async {
    final response = await supabase.rpc(
      'update_order_status',
      params: {
        'p_order_id':   orderId,
        'p_new_status': newStatus,
        'p_cash_id':    cashId,
        'p_user':       currentUserId,
      },
    );

    if (response == null || (response as List).isEmpty) {
      throw Exception('No response from update_order_status');
    }

    return Map<String, dynamic>.from(response.first);
  }

  // ── Legacy direct update (kept for reference) ─────────────
  static Future<void> updateOrderStatus({
    required int orderId,
    required String status,
  }) async {
    await supabase
        .from('orders')
        .update({'status': status})
        .eq('id', orderId);
  }

  static Future<void> applyOrderStatusWithCashInflow({
    required int orderId,
    required String newStatus,
    required double totalAmount,
    required double deliveryAmount,
  }) async {
    final user = null;

    await supabase.rpc('apply_cash_inflow', params: {
      'p_created_by':       user?.id,
      'p_order_id':         orderId,
      'p_total':            totalAmount,
      'p_delivery':         deliveryAmount,
      'p_transaction_date': DateTime.now().toUtc().toIso8601String(),
    });

    await supabase
        .from('orders')
        .update({'status': newStatus})
        .eq('id', orderId);
  }

  // ── Delivery Orders ───────────────────────────────────────
  static Future<List<dynamic>> getDeliveryOrders({required DateTime date}) async {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0).toUtc();
    final end   = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc();

    final response = await supabase
        .from('orders')
        .select('''
          id, status, total_amount, delivery_price, delivery_type, order_date,
          customers(id, name, phone, address, latitude, longitude),
          order_items(
            id, quantity, sell_price, is_prepared,
            products(id, name, unit),
            product_variants(id, name)
          )
        ''')
        .eq('delivery_type', 'delivery')
        .gte('order_date', start.toIso8601String())
        .lte('order_date', end.toIso8601String())
        .order('order_date', ascending: false);

    return response;
  }

  // ── Transactions ──────────────────────────────────────────
  static Future<List<dynamic>> getTransactions({required DateTime date}) async {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0).toUtc();
    final end   = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc();

    final response = await supabase
        .from('transactions')
        .select('id, type, category_id, reference_type, reference_id, amount, description, status, transaction_date, transaction_categories(id, name, type)')
        .gte('transaction_date', start.toIso8601String())
        .lte('transaction_date', end.toIso8601String())
        .order('transaction_date', ascending: false);

    return response;
  }

  static Future<Map<String, dynamic>> getTransactionDetail({
    required int txId,
    int? categoryId,
  }) async {
    final tx = await supabase
        .from('transactions')
        .select('*, transaction_categories(id, name, type)')
        .eq('id', txId)
        .single();

    if (categoryId == 1 && tx['reference_id'] != null) {
      try {
        final order = await supabase
            .from('orders')
            .select('id, status, order_items(id, quantity, sell_price, is_prepared, products(id, name, unit), product_variants(id, name))')
            .eq('id', tx['reference_id'] as int)
            .single();
        tx['order_items'] = order['order_items'];
      } catch (_) {
        tx['order_items'] = [];
      }
    }

    if (categoryId == 3) {
      final items = await supabase
          .from('transaction_items')
          .select('*, products(id, name, unit)')
          .eq('transaction_id', txId)
          .order('id');
      tx['transaction_items'] = items;
    }

    return Map<String, dynamic>.from(tx);
  }
}