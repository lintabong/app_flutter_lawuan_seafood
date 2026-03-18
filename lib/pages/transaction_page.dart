import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class TransactionPage extends StatefulWidget {
  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  List transactions = [];
  bool loading = true;
  DateTime selectedDate = DateTime.now();

  // Track which card indexes are expanded
  final Set<int> _expanded = {};

  static const Color _pink   = Color(0xFFEC4899);
  static const Color _pinkBg = Color(0xFF2D0A1E);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future _load() async {
    setState(() { loading = true; _expanded.clear(); });
    final data = await SupabaseService.getTransactions(date: selectedDate);
    setState(() { transactions = data; loading = false; });
  }

  Future _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: _pink,
            surface: const Color(0xFF161B27),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF161B27),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      _load();
    }
  }

  // ── Helpers ──────────────────────────────────────────────

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num = double.tryParse(price.toString()) ?? 0;
    final str = num.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _formatDateTime(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${dt.day} ${m[dt.month - 1]} ${dt.year}, "
             "${_pad(dt.hour)}:${_pad(dt.minute)}";
    } catch (_) { return raw; }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _formatFullDate(DateTime d) {
    const months = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Category / status style maps ─────────────────────────

  Map<String, dynamic> _categoryStyle(int? catId, String? type) {
    if (catId == 1) { 
      return {
        'label': 'Product Sales',     'color': const Color(0xFF10B981),
        'bg':    const Color(0xFF062318), 'icon': Icons.point_of_sale_rounded,
        'income': true,
      };
    }
    if (catId == 2) { 
      return {
        'label': 'Delivery Fees',     'color': const Color(0xFF06B6D4),
        'bg':    const Color(0xFF0C2A3A), 'icon': Icons.delivery_dining_rounded,
        'income': true,
      };
    }
    if (catId == 3 || catId == 4) {
      return {
        'label': 'Product Purchases', 'color': const Color(0xFFF97316),
        'bg':    const Color(0xFF2D1200), 'icon': Icons.shopping_bag_rounded,
        'income': false,
      };
    }
    switch (type) {
      case 'income':    return {'label': 'Income',    'color': const Color(0xFF10B981), 'bg': const Color(0xFF062318), 'icon': Icons.trending_up_rounded,    'income': true};
      case 'expense':   return {'label': 'Expense',   'color': const Color(0xFFEF4444), 'bg': const Color(0xFF2D0A0A), 'icon': Icons.trending_down_rounded,   'income': false};
      case 'purchase':  return {'label': 'Purchase',  'color': const Color(0xFFF97316), 'bg': const Color(0xFF2D1200), 'icon': Icons.shopping_bag_rounded,    'income': false};
      case 'transfer':  return {'label': 'Transfer',  'color': const Color(0xFF8B5CF6), 'bg': const Color(0xFF1C1030), 'icon': Icons.swap_horiz_rounded,      'income': true};
      case 'adjustment':return {'label': 'Adjustment','color': const Color(0xFF94A3B8), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.tune_rounded,            'income': true};
      default:          return {'label': 'Other',     'color': const Color(0xFF64748B), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.receipt_rounded,         'income': true};
    }
  }

  Map<String, dynamic> _statusStyle(String? s) {
    switch (s) {
      case 'draft':    return {'color': const Color(0xFF94A3B8), 'bg': const Color(0xFF1A1F2E)};
      case 'posted':   return {'color': const Color(0xFF6C63FF), 'bg': const Color(0xFF1E1B4B)};
      case 'partial':  return {'color': const Color(0xFFF59E0B), 'bg': const Color(0xFF2D1F0A)};
      case 'settled':  return {'color': const Color(0xFF10B981), 'bg': const Color(0xFF062318)};
      case 'voided':   return {'color': const Color(0xFFEF4444), 'bg': const Color(0xFF2D0A0A)};
      case 'reversed': return {'color': const Color(0xFFF97316), 'bg': const Color(0xFF2D1200)};
      default:         return {'color': const Color(0xFF64748B), 'bg': const Color(0xFF1A1F2E)};
    }
  }

  // ── Summary ───────────────────────────────────────────────

  double _totalIn() => transactions.fold(0.0, (s, t) {
    final style = _categoryStyle(t['category_id'], t['type']);
    return s + ((style['income'] as bool)
        ? (double.tryParse(t['amount'].toString()) ?? 0) : 0);
  });

  double _totalOut() => transactions.fold(0.0, (s, t) {
    final style = _categoryStyle(t['category_id'], t['type']);
    return s + (!(style['income'] as bool)
        ? (double.tryParse(t['amount'].toString()) ?? 0) : 0);
  });

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildDateBar(),
            if (!loading) _buildSummary(),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2333),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A3040), width: 1),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF94A3B8), size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Transactions", style: TextStyle(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800, letterSpacing: -0.5,
                )),
                if (!loading)
                  Text("${transactions.length} records",
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _pinkBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _pink.withOpacity(0.3), width: 1),
            ),
            child: const Icon(Icons.add_rounded, color: _pink, size: 22),
          ),
        ],
      ),
    );
  }

  // ── Date bar ──────────────────────────────────────────────

  Widget _buildDateBar() {
    final isToday = _isToday(selectedDate);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: GestureDetector(
        onTap: () => _pickDate(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF222840), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: _pinkBg, borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.calendar_today_rounded,
                    size: 15, color: _pink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? "Today" : _formatFullDate(selectedDate),
                      style: const TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      isToday
                          ? _formatFullDate(selectedDate)
                          : "Tap to change",
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.unfold_more_rounded,
                  color: Color(0xFF4A5568), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Summary ───────────────────────────────────────────────

  Widget _buildSummary() {
    final inAmt  = _totalIn();
    final outAmt = _totalOut();
    final net    = inAmt - outAmt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Row(
        children: [
          Expanded(child: _summaryTile("Income",   inAmt,
              const Color(0xFF10B981), const Color(0xFF062318),
              Icons.arrow_downward_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _summaryTile("Expenses", outAmt,
              const Color(0xFFF97316), const Color(0xFF2D1200),
              Icons.arrow_upward_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _summaryTile("Net", net,
              net >= 0 ? const Color(0xFF6C63FF) : const Color(0xFFEF4444),
              net >= 0 ? const Color(0xFF1E1B4B) : const Color(0xFF2D0A0A),
              Icons.account_balance_rounded)),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, double amount,
      Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF222840), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 8),
          Text(_formatPrice(amount),
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis),
          Text(label, style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── List body ─────────────────────────────────────────────

  Widget _buildBody() {
    if (loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 36, height: 36,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _pink)),
            const SizedBox(height: 16),
            const Text("Loading transactions...",
                style: TextStyle(
                    color: Color(0xFF4A5568), fontSize: 14)),
          ],
        ),
      );
    }
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                color: Color(0xFF2A3040), size: 64),
            const SizedBox(height: 16),
            const Text("No transactions on this date",
                style: TextStyle(
                    color: Color(0xFF4A5568), fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: transactions.length,
      itemBuilder: (ctx, i) => _buildCard(i, transactions[i] as Map),
    );
  }

  // card
  Widget _buildCard(int index, Map tx) {
    final catId    = tx['category_id'] as int?;
    final style    = _categoryStyle(catId, tx['type']);
    final color    = style['color'] as Color;
    final bg       = style['bg'] as Color;
    final icon     = style['icon'] as IconData;
    final isIncome = style['income'] as bool;
    final amount   = double.tryParse(tx['amount'].toString()) ?? 0;
    final statusSt = _statusStyle(tx['status'] as String?);
    final isExpanded = _expanded.contains(index);

    // ── Detect items ─────────────────────────────────────
    // sale: tx['order']['order_items']
    // purchase: tx['items']
    final orderMap   = tx['order'] as Map?;
    final orderItems = (orderMap?['order_items'] as List?) ?? [];
    final purchItems = (tx['items'] as List?) ?? [];
    final hasItems   = orderItems.isNotEmpty || purchItems.isNotEmpty;

    // ── Order reference ───────────────────────────────────
    final orderId = orderMap?['id'];
    final custName = (orderMap?['customers'] as Map?)?['name'];
    final supplierMap  = tx['suppliers'] as Map?;
    final supplierName = supplierMap?['name'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded
              ? color.withOpacity(0.25)
              : const Color(0xFF222840),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ── Tap row (always visible) ────────────────────
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              splashColor: color.withOpacity(0.06),
              onTap: hasItems
                  ? () => setState(() {
                        if (isExpanded) {
                          _expanded.remove(index);
                        } else {
                          _expanded.add(index);
                        }
                      })
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category icon
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(13)),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),

                    // Middle info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category name
                          Text(
                            style['label'] as String,
                            style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),

                          // Order ref or description
                          if (supplierName != null)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2D1200),
                                    borderRadius:
                                        BorderRadius.circular(5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                          Icons.storefront_rounded,
                                          size: 11,
                                          color: Color(0xFFF97316)),
                                      const SizedBox(width: 4),
                                      Text(
                                        supplierName,
                                        style: const TextStyle(
                                            color: Color(0xFFF97316),
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else if (orderId != null)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2D1F0A),
                                    borderRadius:
                                        BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'Order #$orderId',
                                    style: const TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (custName != null) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      custName,
                                      style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else if ((tx['description'] ?? '')
                              .toString()
                              .isNotEmpty)
                            Text(
                              tx['description'],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                          const SizedBox(height: 5),

                          // Date + status row
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 11,
                                  color: Color(0xFF4A5568)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatDateTime(
                                      tx['transaction_date'] as String?),
                                  style: const TextStyle(
                                      color: Color(0xFF4A5568),
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Right: amount + status + chevron
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${isIncome ? '+' : '−'}Rp ${_formatPrice(amount)}",
                          style: TextStyle(
                            color: isIncome
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF97316),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusSt['bg'],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _capitalize(tx['status'] as String? ?? ''),
                            style: TextStyle(
                                color: statusSt['color'],
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (hasItems) ...[
                          const SizedBox(height: 6),
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF4A5568),
                                size: 18),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Expanded items ──────────────────────────────
          if (isExpanded && hasItems)
            _buildExpandedItems(
              tx: tx,
              catId: catId,
              color: color,
              orderItems: orderItems,
              purchItems: purchItems,
              amount: amount,
            ),
        ],
      ),
    );
  }

  // ── Expanded items section ────────────────────────────────

  Widget _buildExpandedItems({
    required Map tx,
    required int? catId,
    required Color color,
    required List orderItems,
    required List purchItems,
    required double amount,
  }) {
    final orderMap = tx['order'] as Map?;
    final deliveryPrice =
        double.tryParse(orderMap?['delivery_price']?.toString() ?? '0') ?? 0;

    return Column(
      children: [
        // Divider
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          height: 1,
          color: const Color(0xFF222840),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Sale: order items ────────────────────────
              if (orderItems.isNotEmpty) ...[
                _expandLabel("ITEMS", "${orderItems.length}"),
                const SizedBox(height: 8),
                ...orderItems.map((item) {
                  final item_ = item as Map;
                  final product = item_['products'] as Map? ?? {};
                  final variant = item_['product_variants'] as Map?;
                  final qty   = double.tryParse(
                      item_['quantity'].toString()) ?? 0;
                  final price = double.tryParse(
                      item_['sell_price'].toString()) ?? 0;
                  return _itemTile(
                    name: product['name'] ?? '—',
                    sub: (variant?['name'] != null &&
                            variant!['name'] != 'default')
                        ? variant['name']
                        : null,
                    qty: qty,
                    unit: product['unit'],
                    price: price,
                    color: color,
                  );
                }),

                // Delivery row (if any)
                if (deliveryPrice > 0) ...[
                  const SizedBox(height: 4),
                  _deliveryTile(deliveryPrice),
                ],

                const SizedBox(height: 8),
                _totalTile(amount, color),
              ],

              // ── Purchase: transaction items ───────────────
              if (purchItems.isNotEmpty) ...[
                // Supplier row
                if (tx['supplier_id'] != null)
                  // _supplierChip(tx),
                const SizedBox(height: 8),
                _expandLabel("ITEMS", "${purchItems.length}"),
                const SizedBox(height: 8),
                ...purchItems.map((item) {
                  final item_ = item as Map;
                  final product = item_['products'] as Map? ?? {};
                  final qty   = double.tryParse(
                      (item_['quantity'] ?? 1).toString()) ?? 1;
                  final price = double.tryParse(
                      (item_['price'] ?? 0).toString()) ?? 0;
                  return _itemTile(
                    name: product['name'] ?? '—',
                    sub: null,
                    qty: qty,
                    unit: product['unit'],
                    price: price,
                    color: color,
                  );
                }),
                const SizedBox(height: 8),
                _totalTile(amount, color),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Small helpers for expanded section ────────────────────

  Widget _expandLabel(String label, String count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0)),
        Text(count, style: const TextStyle(
            color: Color(0xFF4A5568), fontSize: 10)),
      ],
    );
  }

  Widget _itemTile({
    required String name,
    String? sub,
    required double qty,
    String? unit,
    required double price,
    required Color color,
  }) {
    final lineTotal = qty * price;
    final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2333), width: 1),
      ),
      child: Row(
        children: [
          // Product icon dot
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
                color: color.withOpacity(0.6),
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
                if (sub != null) ...[
                  const SizedBox(height: 1),
                  Text(sub, style: const TextStyle(
                      color: Color(0xFF6C63FF), fontSize: 13)),
                ],
                const SizedBox(height: 2),
                Text(
                  "$qtyStr ${unit ?? ''} × Rp ${_formatPrice(price)}",
                  style: const TextStyle(
                      color: Color(0xFF4A5568), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            "Rp ${_formatPrice(lineTotal)}",
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _deliveryTile(double price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2A3A).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF06B6D4).withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.delivery_dining_rounded,
              size: 14, color: Color(0xFF06B6D4)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text("Delivery fee",
                style: TextStyle(
                    color: Color(0xFF06B6D4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Text("Rp ${_formatPrice(price)}",
              style: const TextStyle(
                  color: Color(0xFF06B6D4),
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // Widget _supplierChip(Map tx) {
  //   // supplier name might be embedded or just an id
  //   // final supplierId = tx['supplier_id'];
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  //     decoration: BoxDecoration(
  //       color: const Color(0xFF2D1200),
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(
  //           color: const Color(0xFFF97316).withOpacity(0.2), width: 1),
  //     ),
  //   );
  // }

  Widget _totalTile(double total, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Total",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          Text("Rp ${_formatPrice(total)}",
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
