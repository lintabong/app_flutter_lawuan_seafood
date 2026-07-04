import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class SupabaseService {

  static String? get currentUserId => supabase.auth.currentUser?.id;

  static Future<double> getCashBalance(int cashId) async {
    final res = await supabase
        .from('cash')
        .select('balance')
        .eq('id', cashId)
        .single();

    return (res['balance'] as num).toDouble();
  }

  static Future<int> getActiveVariantCount() async {
    final res = await supabase
        .from('product_variants')
        .select('id, products!inner(is_active)')
        .eq('products.is_active', true);

    return (res as List).length;
  }

  static Future<List<dynamic>> getProducts() async {
    final response = await supabase
        .from('products')
        .select('*, product_variants(id, name, unit, buy_price, sell_price)')
        .eq('is_active', true)
        .order('name');
    return response;
  }

  static Future<List<dynamic>> getProductsWithVariants() async {
    final response = await supabase
        .from('products')
        .select('''
          id, name, unit, sell_price, category_id, is_active,
          product_variants(
            id, product_id, name, unit,
            buy_price, sell_price, stock,
            conversion_factor, is_active
          )
        ''')
        .eq('is_active', true)
        .order('name');
    return response;
  }

  /// Edit product ATAU variant 'default' — dua-duanya sinkron
  /// lewat 1 RPC (lihat update_product_rpc.sql).
  static Future<void> updateProductWithDefaultVariant({
    required int productId,
    required double stock,
    required double sellPrice,
    required double buyPrice,
  }) async {
    await supabase.rpc(
      'update_product_with_default_variant',
      params: {
        'p_product_id': productId,
        'p_stock': stock,
        'p_sell_price': sellPrice,
        'p_buy_price': buyPrice,
      },
    );
  }

  /// Create product baru + variant default sekaligus.
  /// Return: product id baru.
  static Future<int> insertProductWithDefaultVariant({
    required String name,
    required int categoryId,
    required String unit,
    required double buyPrice,
    required double sellPrice,
    required double stock,
  }) async {
    final response = await supabase.rpc(
      'insert_product_with_default_variant',
      params: {
        'p_name': name,
        'p_category_id': categoryId,
        'p_unit': unit.isNotEmpty ? unit : 'kg',
        'p_buy_price': buyPrice,
        'p_sell_price': sellPrice,
        'p_stock': stock,
      },
    );
    return (response as num).toInt();
  }

  /// GANTIKAN insertProductVariant lama dengan versi ini —
  /// sekarang ikut menyimpan conversion_factor (dipakai fitur
  /// Convert Variant; default 1 kalau tidak diisi).
  static Future<Map<String, dynamic>> insertProductVariant({
    required int productId,
    required String name,
    required String unit,
    required double stock,
    required double sellPrice,
    required double buyPrice,
    double conversionFactor = 1,
  }) async {
    final response = await supabase
        .from('product_variants')
        .insert({
          'product_id': productId,
          'name': name,
          'unit': unit.isNotEmpty ? unit : null,
          'stock': stock,
          'sell_price': sellPrice,
          'buy_price': buyPrice,
          'conversion_factor': conversionFactor,
          'is_active': true,
        })
        .select(
            'id, product_id, name, unit, buy_price, sell_price, stock, conversion_factor, is_active')
        .single();
    return response;
  }

  static Future<void> updateProduct({
    required int productId,
    required double stock,
    required double sellPrice,
    required double buyPrice,
  }) async {
    await supabase.from('products').update({
      'stock':      stock,
      'sell_price': sellPrice,
      'buy_price':  buyPrice,
    }).eq('id', productId);
  }

  // ── Product Variants ──────────────────────────────────────

  static Future<List<dynamic>> getProductVariants(int productId) async {
    final response = await supabase
        .from('product_variants')
        .select('id, product_id, name, unit, buy_price, sell_price, stock, is_active')
        .eq('product_id', productId)
        .order('name');
    return response;
  }

  static Future<void> updateProductVariant({
    required int variantId,
    required double stock,
    required double sellPrice,
    required double buyPrice,
  }) async {
    await supabase.from('product_variants').update({
      'stock': stock,
      'sell_price': sellPrice,
      'buy_price': buyPrice,
    }).eq('id', variantId);
  }

  static Future<List<dynamic>> getCustomers() async {
    final response = await supabase
        .from('customers')
        .select('id, name, phone, address, latitude, longitude')
        .order('name');
    return response;
  }

  static Future<void> insertCustomer(Map<String, dynamic> data) async {
    await supabase.from('customers').insert(data);
  }
 
  static Future<void> updateCustomer(int id, Map<String, dynamic> data) async {
    await supabase.from('customers').update(data).eq('id', id);
  }
 
  static Future<void> deleteCustomer(int id) async {
    await supabase.from('customers').delete().eq('id', id);
  }

  static Future<List<dynamic>> getSuppliers() async {
    final response = await supabase
        .from('suppliers')
        .select('id, name, phone, address')
        .eq('is_active', true)
        .order('name');
    return response;
  }

  static Future<Map<String, dynamic>> expenseTransaction({
    required String categoryName,
    required double amount,
    required String status,
    required String description,
    required DateTime transactionDate,
    int cashId = 1,
  }) async {
    final response = await supabase.rpc(
      'expense_transaction',
      params: {
        'p_category_name': categoryName,
        'p_amount': amount,
        'p_cash_id': cashId,
        'p_description': description,
        'p_status': status,
        'p_created_by': currentUserId,
        'p_transaction_date': transactionDate.toUtc().toIso8601String(),
      },
    );
    return Map<String, dynamic>.from(response.first);
  }

  static Future<Map<String, dynamic>> productPurchaseTransaction({
    required int supplierId,
    required String status,
    required String description,
    required DateTime transactionDate,
    required List<Map<String, dynamic>> items,
    int cashId = 1,
  }) async {
    final response = await supabase.rpc(
      'product_purchase_transaction',
      params: {
        'p_cash_id': cashId,
        'p_supplier_id': supplierId,
        'p_items': items,
        'p_status': status,
        'p_description': description,
        'p_created_by': currentUserId,
        'p_transaction_date': transactionDate.toUtc().toIso8601String(),
      },
    );
    return Map<String, dynamic>.from(response.first);
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
    String? name,
    String? deliveryType,
    bool withItems = false,
  }) async {
    final int from = (page - 1) * pageSize;
    final int to = from + pageSize - 1;

    var selectQuery = '''
      id, status, total_amount, delivery_price, delivery_type, order_date,
      customers(id, name, phone, address, latitude, longitude)
    ''';

    if (withItems) {
      selectQuery += '''
        ,order_items(
          id, quantity, sell_price, is_prepared,
          products(id, name, unit),
          product_variants(id, product_id, name, unit, buy_price, sell_price, stock)
        )
      ''';
    }

    var query = supabase.from('orders').select(selectQuery);

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    } else {
      query = query.inFilter('status', [
        'pending', 'paid', 'prepared', 'picked up', 'delivered',
      ]);
    }

    if (date != null) {
      final start = DateTime(date.year, date.month, date.day).toUtc();
      final end   = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc();
      query = query
          .gte('order_date', start.toIso8601String())
          .lte('order_date', end.toIso8601String());
    }

    if (deliveryType != null && deliveryType.isNotEmpty) {
      query = query.eq('delivery_type', deliveryType);
    }

    if (name != null && name.isNotEmpty) {
      query = query.ilike('customers.name', '%$name%');
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

  static Future<void> updateOrderStatus({
    required int orderId,
    required String status,
  }) async {
    await supabase
        .from('orders')
        .update({'status': status})
        .eq('id', orderId);
  }

  static Future<List<dynamic>> getTransactions({required DateTime date}) async {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0).toUtc();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc();

    // 1️⃣ Fetch transactions
    final transactions = await supabase
        .from('transactions')
        .select('''
          id,
          type,
          category_id,
          reference_type,
          reference_id,
          amount,
          description,
          status,
          transaction_date,
          supplier_id,
          suppliers(id, name),
          transaction_categories(id, name, type)
        ''')
        .gte('transaction_date', start.toIso8601String())
        .lte('transaction_date', end.toIso8601String())
        .inFilter('status', ['partial', 'draft', 'posted'])
        .order('transaction_date', ascending: false);

    if (transactions.isEmpty) return [];

    // 2️⃣ Collect reference IDs
    final orderIds = <int>[];
    final transactionIds = <int>[];

    for (final t in transactions) {
      if (t['reference_type'] == 'order' && t['reference_id'] != null) {
        orderIds.add(t['reference_id']);
      }

      if (t['reference_type'] == 'transaction_items') {
        transactionIds.add(t['id']);
      }
    }

    // 3️⃣ Fetch orders
    Map<int, dynamic> ordersMap = {};
    if (orderIds.isNotEmpty) {
      final orders = await supabase
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
          .inFilter('id', orderIds);

      for (final o in orders) {
        ordersMap[o['id']] = o;
      }
    }

    // 4️⃣ Fetch transaction_items + products
    Map<int, List<dynamic>> itemsMap = {};
    if (transactionIds.isNotEmpty) {
      final items = await supabase
          .from('transaction_items')
          .select('''
            id,
            transaction_id,
            product_id,
            quantity,
            price,
            subtotal,
            products(id,name,unit)
          ''')
          .inFilter('transaction_id', transactionIds);

      for (final item in items) {
        final tid = item['transaction_id'];

        itemsMap.putIfAbsent(tid, () => []);
        itemsMap[tid]!.add(item);
      }
    }

    // 5️⃣ Merge result
    final result = transactions.map((t) {
      if (t['reference_type'] == 'order') {
        t['order'] = ordersMap[t['reference_id']];
      }
      if (t['reference_type'] == 'transaction_items') {
        t['items'] = itemsMap[t['id']] ?? [];
      }

      return t;
    }).toList();

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════
// TAMBAHAN UNTUK lib/services/supabase_service.dart
// Copy method-method di bawah ini ke dalam class SupabaseService.
// ═══════════════════════════════════════════════════════════════════

  // ── Variant Conversion ────────────────────────────────────

  /// Products + semua variant lengkap dengan stock & conversion_factor.
  /// Dipakai oleh halaman converter (getProducts() yang lama tidak
  /// mengambil stock & conversion_factor, jadi dibuat terpisah agar
  /// tidak mengganggu halaman lain).
  static Future<List<dynamic>> getProductsForConversion() async {
    final response = await supabase
        .from('products')
        .select('''
          id, name, unit,
          product_variants(
            id, name, unit, stock, conversion_factor, is_active
          )
        ''')
        .eq('is_active', true)
        .order('name');
    return response;
  }

  /// Panggil RPC convert_product_variant.
  ///
  /// direction:
  ///   'pack'   → default berkurang (qty × factor), variant bertambah qty
  ///   'unpack' → variant berkurang qty, default bertambah (qty × factor)
  ///
  /// Return: { ledger_id, default_stock, variant_stock }
  static Future<Map<String, dynamic>> convertProductVariant({
    required int productId,
    required int variantId,
    required double quantity,
    String direction = 'pack',
    String? note,
  }) async {
    final response = await supabase.rpc(
      'convert_product_variant',
      params: {
        'p_product_id': productId,
        'p_variant_id': variantId,
        'p_quantity': quantity,
        'p_direction': direction,
        'p_note': (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        'p_created_by': currentUserId,
      },
    );

    if (response == null || (response as List).isEmpty) {
      throw Exception('No response from convert_product_variant');
    }

    return Map<String, dynamic>.from(response.first);
  }

  /// Riwayat konversi dari variant_conversion_ledger.
  /// productId null = semua product.
  ///
  /// Nama FK mengikuti auto-naming Postgres dari definisi table:
  ///   variant_conversion_ledger_from_variant_id_fkey
  ///   variant_conversion_ledger_to_variant_id_fkey
  static Future<List<dynamic>> getConversionLedger({
    int? productId,
    int limit = 20,
  }) async {
    var query = supabase.from('variant_conversion_ledger').select('''
      id, quantity, conversion_factor, base_qty, note, created_at,
      products(id, name, unit),
      from_variant:product_variants!variant_conversion_ledger_from_variant_id_fkey(id, name),
      to_variant:product_variants!variant_conversion_ledger_to_variant_id_fkey(id, name)
    ''');

    if (productId != null) {
      query = query.eq('product_id', productId);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return response;
  }

  // ═══════════════════════════════════════════════════════════════════
// TAMBAHAN UNTUK lib/services/supabase_service.dart
// Dipakai oleh KEDUA opsi (full file maupun yang dipisah).
// Copy method ini ke dalam class SupabaseService.
// getActiveVariantCount() boleh dihapus kalau sudah tidak dipakai
// halaman lain.
// ═══════════════════════════════════════════════════════════════════

  /// Total stock setara kg dari semua variant aktif (product aktif).
  /// Rumus: SUM(stock × conversion_factor).
  ///
  /// Variant 'default' punya factor 1, jadi otomatis ikut terhitung
  /// apa adanya. Contoh: default 4 kg + 6 cup 500gr (factor 0.5)
  /// = 4 + 3 = 7 kg.
  ///
  /// Dihitung di sisi client karena jumlah variant masih kecil.
  /// Kalau nanti sudah ribuan baris, pindahkan ke RPC agregat di
  /// Postgres agar hanya 1 angka yang dikirim lewat network.
  static Future<double> getTotalStockKg() async {
    final res = await supabase
        .from('product_variants')
        .select('stock, conversion_factor, products!inner(is_active)')
        .eq('is_active', true)
        .eq('products.is_active', true);

    double total = 0;
    for (final row in (res as List)) {
      final stock =
          double.tryParse(row['stock']?.toString() ?? '0') ?? 0;
      final factor =
          double.tryParse(row['conversion_factor']?.toString() ?? '1') ?? 1;
      total += stock * factor;
    }
    return total;
  }

  // ── Reports ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSalesSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final res = await supabase.rpc('report_sales_summary', params: {
      'p_start': start.toUtc().toIso8601String(),
      'p_end': end.toUtc().toIso8601String(),
    });

    final list = res as List;
    if (list.isEmpty) {
      return {
        'order_count': 0,
        'items_revenue': 0,
        'delivery_revenue': 0,
        'total_revenue': 0,
        'total_cogs': 0,
        'gross_profit': 0,
        'total_expense': 0,
        'total_purchase': 0,
      };
    }
    return Map<String, dynamic>.from(list.first as Map);
  }

  static Future<List<dynamic>> getProductSales({
    required DateTime start,
    required DateTime end,
  }) async {
    final res = await supabase.rpc('report_product_sales', params: {
      'p_start': start.toUtc().toIso8601String(),
      'p_end': end.toUtc().toIso8601String(),
    });
    return res as List;
  }
  
  /// Products + variant lengkap dengan buy_price — dipakai halaman
  /// product conversion (perlu buy_price untuk preview WAC).
  static Future<List<dynamic>> getProductsForProductConversion() async {
    final response = await supabase
        .from('products')
        .select('''
          id, name, unit,
          product_variants(
            id, name, unit, stock, buy_price,
            conversion_factor, is_active
          )
        ''')
        .eq('is_active', true)
        .order('name');
    return response;
  }

  /// RPC convert_product.
  /// Return: { ledger_id, from_stock, to_stock, new_avg_cost }
  static Future<Map<String, dynamic>> convertProduct({
    required int fromProductId,
    required int toProductId,
    required double qtyFrom,
    required double qtyTo,
    String? note,
  }) async {
    final response = await supabase.rpc(
      'convert_product',
      params: {
        'p_from_product_id': fromProductId,
        'p_to_product_id': toProductId,
        'p_qty_from': qtyFrom,
        'p_qty_to': qtyTo,
        'p_note':
            (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        'p_created_by': currentUserId,
      },
    );
    if (response == null || (response as List).isEmpty) {
      throw Exception('No response from convert_product');
    }
    return Map<String, dynamic>.from(response.first);
  }

  /// Riwayat konversi product terakhir.
  static Future<List<dynamic>> getProductConversionLedger(
      {int limit = 10}) async {
    final response = await supabase
        .from('product_conversion_ledger')
        .select('''
          id, qty_from, qty_to, unit_cost, total_value,
          new_avg_cost, note, created_at,
          from_product:products!product_conversion_ledger_from_product_id_fkey(id, name),
          to_product:products!product_conversion_ledger_to_product_id_fkey(id, name)
        ''')
        .order('created_at', ascending: false)
        .limit(limit);
    return response;
  }
}
