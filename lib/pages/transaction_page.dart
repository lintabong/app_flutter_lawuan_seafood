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

  // Design tokens
  static const Color _pink    = Color(0xFFEC4899);
  static const Color _pinkBg  = Color(0xFF2D0A1E);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future _load() async {
    setState(() => loading = true);
    final data = await SupabaseService.getTransactions(date: selectedDate);
    setState(() { transactions = data; loading = false; });
  }

  Future _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: _pink,
            surface: Color(0xFF161B27),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: Color(0xFF161B27),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      _load();
    }
  }

  // ── helpers ──────────────────────────────────────────────

  String _formatPrice(dynamic price, {bool signed = false}) {
    if (price == null) return '0';
    final num = double.tryParse(price.toString()) ?? 0;
    final str = num.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    final formatted = buffer.toString();
    if (signed) return num >= 0 ? '+ $formatted' : '- $formatted';
    return 'Rp $formatted';
  }

  String _formatDateShort(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${dt.day} ${m[dt.month - 1]}, ${_pad(dt.hour)}:${_pad(dt.minute)}";
    } catch (_) { return raw; }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Map<String, dynamic> _categoryStyle(int? catId, String? type) {
    if (catId == 1) return {
      'label': 'Product Sales', 'color': Color(0xFF10B981),
      'bg': Color(0xFF062318), 'icon': Icons.point_of_sale_rounded, 'income': true,
    };
    if (catId == 2) return {
      'label': 'Delivery Fees', 'color': Color(0xFF06B6D4),
      'bg': Color(0xFF0C2A3A), 'icon': Icons.delivery_dining_rounded, 'income': true,
    };
    if (catId == 3) return {
      'label': 'Product Purchases', 'color': Color(0xFFF97316),
      'bg': Color(0xFF2D1200), 'icon': Icons.shopping_bag_rounded, 'income': false,
    };
    // Fallback by type
    switch (type) {
      case 'income':    return {'label': 'Income',    'color': Color(0xFF10B981), 'bg': Color(0xFF062318), 'icon': Icons.trending_up_rounded,    'income': true};
      case 'expense':   return {'label': 'Expense',   'color': Color(0xFFEF4444), 'bg': Color(0xFF2D0A0A), 'icon': Icons.trending_down_rounded,   'income': false};
      case 'transfer':  return {'label': 'Transfer',  'color': Color(0xFF8B5CF6), 'bg': Color(0xFF1C1030), 'icon': Icons.swap_horiz_rounded,      'income': true};
      case 'adjustment':return {'label': 'Adjustment','color': Color(0xFF94A3B8), 'bg': Color(0xFF1A1F2E), 'icon': Icons.tune_rounded,            'income': true};
      default:          return {'label': 'Other',     'color': Color(0xFF64748B), 'bg': Color(0xFF1A1F2E), 'icon': Icons.receipt_rounded,         'income': true};
    }
  }

  Map<String, dynamic> _statusStyle(String? s) {
    switch (s) {
      case 'draft':     return {'color': Color(0xFF94A3B8), 'bg': Color(0xFF1A1F2E)};
      case 'posted':    return {'color': Color(0xFF6C63FF), 'bg': Color(0xFF1E1B4B)};
      case 'partial':   return {'color': Color(0xFFF59E0B), 'bg': Color(0xFF2D1F0A)};
      case 'settled':   return {'color': Color(0xFF10B981), 'bg': Color(0xFF062318)};
      case 'voided':    return {'color': Color(0xFFEF4444), 'bg': Color(0xFF2D0A0A)};
      case 'reversed':  return {'color': Color(0xFFF97316), 'bg': Color(0xFF2D1200)};
      default:          return {'color': Color(0xFF64748B), 'bg': Color(0xFF1A1F2E)};
    }
  }

  // ── summary ───────────────────────────────────────────────

  double _totalIn() => transactions.fold(0, (s, t) {
    final style = _categoryStyle(t['category_id'], t['type']);
    return s + ((style['income'] as bool) ? (double.tryParse(t['amount'].toString()) ?? 0) : 0);
  });

  double _totalOut() => transactions.fold(0, (s, t) {
    final style = _categoryStyle(t['category_id'], t['type']);
    return s + (!(style['income'] as bool) ? (double.tryParse(t['amount'].toString()) ?? 0) : 0);
  });

  // ── build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F1117),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildDateBar(context),
            if (!loading) _buildSummary(),
            SizedBox(height: 8),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Color(0xFF1E2333),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF2A3040), width: 1),
              ),
              child: Icon(Icons.arrow_back_rounded, color: Color(0xFF94A3B8), size: 20),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Transactions", style: TextStyle(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800, letterSpacing: -0.5,
                )),
                if (!loading)
                  Text("${transactions.length} records", style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
            child: Icon(Icons.add_rounded, color: _pink, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBar(BuildContext context) {
    final isToday = _isToday(selectedDate);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: GestureDetector(
        onTap: () => _pickDate(context),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFF222840), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _pinkBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.calendar_today_rounded, size: 15, color: _pink),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? "Today" : _formatFullDate(selectedDate),
                      style: TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isToday ? _formatFullDate(selectedDate) : "Tap to change",
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more_rounded, color: Color(0xFF4A5568), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFullDate(DateTime d) {
    const months = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  Widget _buildSummary() {
    final inAmt  = _totalIn();
    final outAmt = _totalOut();
    final net    = inAmt - outAmt;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Row(
        children: [
          Expanded(child: _summaryTile("Income", inAmt, Color(0xFF10B981), Color(0xFF062318), Icons.arrow_downward_rounded)),
          SizedBox(width: 10),
          Expanded(child: _summaryTile("Expenses", outAmt, Color(0xFFF97316), Color(0xFF2D1200), Icons.arrow_upward_rounded)),
          SizedBox(width: 10),
          Expanded(child: _summaryTile("Net", net, net >= 0 ? Color(0xFF6C63FF) : Color(0xFFEF4444),
              net >= 0 ? Color(0xFF1E1B4B) : Color(0xFF2D0A0A), Icons.account_balance_rounded)),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, double amount, Color color, Color bg, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF161B27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFF222840), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color),
          ),
          SizedBox(height: 8),
          Text(
            _formatPrice(amount),
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 36, height: 36,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _pink)),
            SizedBox(height: 16),
            Text("Loading transactions...", style: TextStyle(color: Color(0xFF4A5568), fontSize: 14)),
          ],
        ),
      );
    }
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF2A3040), size: 64),
            SizedBox(height: 16),
            Text("No transactions on this date", style: TextStyle(color: Color(0xFF4A5568), fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: transactions.length,
      itemBuilder: (ctx, i) => _buildCard(ctx, transactions[i]),
    );
  }

  Widget _buildCard(BuildContext context, Map tx) {
    final catId = tx['category_id'] as int?;
    final style = _categoryStyle(catId, tx['type']);
    final color   = style['color'] as Color;
    final bg      = style['bg'] as Color;
    final icon    = style['icon'] as IconData;
    final isIncome = style['income'] as bool;
    final amount  = double.tryParse(tx['amount'].toString()) ?? 0;
    final statusStyle = _statusStyle(tx['status']);

    // Reference label
    String? refLabel;
    if (tx['reference_type'] == 'order' && tx['reference_id'] != null) {
      refLabel = 'Order #${tx['reference_id']}';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Color(0xFF161B27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(0xFF222840), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          splashColor: color.withOpacity(0.06),
          onTap: () => _showDetail(context, tx['id'] as int, catId),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        style['label'],
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      Text(
                        tx['description'] ?? refLabel ?? '—',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          if (refLabel != null) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFF2D1F0A),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(refLabel, style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                            SizedBox(width: 6),
                          ],
                          Text(
                            _formatDateShort(tx['transaction_date']),
                            style: TextStyle(color: Color(0xFF4A5568), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                // Amount + status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${isIncome ? '+' : '-'}Rp ${_formatPrice(amount)}",
                      style: TextStyle(
                        color: isIncome ? Color(0xFF10B981) : Color(0xFFF97316),
                        fontSize: 13, fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusStyle['bg'],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _capitalize(tx['status'] ?? ''),
                        style: TextStyle(color: statusStyle['color'], fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, int txId, int? catId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionDetailSheet(txId: txId, categoryId: catId),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────
// Transaction Detail Bottom Sheet
// ─────────────────────────────────────────────────────────

class _TransactionDetailSheet extends StatefulWidget {
  final int txId;
  final int? categoryId;
  const _TransactionDetailSheet({required this.txId, this.categoryId});

  @override
  State<_TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<_TransactionDetailSheet> {
  Map<String, dynamic>? tx;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future _load() async {
    final data = await SupabaseService.getTransactionDetail(
      txId: widget.txId,
      categoryId: widget.categoryId,
    );
    setState(() { tx = data; loading = false; });
  }

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

  String _formatDate(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${dt.day} ${m[dt.month - 1]} ${dt.year}, ${_pad(dt.hour)}:${_pad(dt.minute)}";
    } catch (_) { return raw; }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Map<String, dynamic> _categoryStyle(int? catId, String? type) {
    if (catId == 1) return {'label': 'Product Sales',     'color': Color(0xFF10B981), 'bg': Color(0xFF062318), 'icon': Icons.point_of_sale_rounded,    'income': true};
    if (catId == 2) return {'label': 'Delivery Fees',     'color': Color(0xFF06B6D4), 'bg': Color(0xFF0C2A3A), 'icon': Icons.delivery_dining_rounded,   'income': true};
    if (catId == 3) return {'label': 'Product Purchases', 'color': Color(0xFFF97316), 'bg': Color(0xFF2D1200), 'icon': Icons.shopping_bag_rounded,      'income': false};
    return                  {'label': 'Transaction',      'color': Color(0xFF94A3B8), 'bg': Color(0xFF1A1F2E), 'icon': Icons.receipt_rounded,           'income': true};
  }

  Map<String, dynamic> _statusStyle(String? s) {
    switch (s) {
      case 'posted':   return {'color': Color(0xFF6C63FF), 'bg': Color(0xFF1E1B4B)};
      case 'settled':  return {'color': Color(0xFF10B981), 'bg': Color(0xFF062318)};
      case 'voided':   return {'color': Color(0xFFEF4444), 'bg': Color(0xFF2D0A0A)};
      case 'reversed': return {'color': Color(0xFFF97316), 'bg': Color(0xFF2D1200)};
      case 'partial':  return {'color': Color(0xFFF59E0B), 'bg': Color(0xFF2D1F0A)};
      default:         return {'color': Color(0xFF94A3B8), 'bg': Color(0xFF1A1F2E)};
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: Color(0xFF161B27),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Color(0xFF222840), width: 1),
        ),
        child: loading
            ? Center(child: SizedBox(width: 32, height: 32,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFEC4899))))
            : _buildContent(sc),
      ),
    );
  }

  Widget _buildContent(ScrollController sc) {
    final t = tx!;
    final catId = t['category_id'] as int?;
    final catStyle = _categoryStyle(catId, t['type']);
    final statusSt = _statusStyle(t['status']);
    final color  = catStyle['color'] as Color;
    final bg     = catStyle['bg'] as Color;
    final isIncome = catStyle['income'] as bool;
    final amount = double.tryParse(t['amount'].toString()) ?? 0;

    // Items depending on category
    final orderItems     = (t['order_items']       as List?) ?? [];
    final txItems        = (t['transaction_items'] as List?) ?? [];

    return ListView(
      controller: sc,
      padding: EdgeInsets.fromLTRB(24, 0, 24, 40),
      children: [
        // Handle
        Center(child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Color(0xFF2A3040), borderRadius: BorderRadius.circular(2))),
        )),

        // Header
        Row(
          children: [
            Container(width: 46, height: 46,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(catStyle['icon'], color: color, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(catStyle['label'], style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text("TX #${t['id']}", style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              ],
            )),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${isIncome ? '+' : '−'}Rp ${_formatPrice(amount)}",
                  style: TextStyle(
                    color: isIncome ? Color(0xFF10B981) : Color(0xFFF97316),
                    fontSize: 16, fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusSt['bg'], borderRadius: BorderRadius.circular(7)),
                  child: Text(_capitalize(t['status'] ?? ''),
                    style: TextStyle(color: statusSt['color'], fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),

        SizedBox(height: 20),

        // Meta info
        Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Color(0xFF0F1117),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFF222840), width: 1),
          ),
          child: Column(
            children: [
              _metaRow(Icons.access_time_rounded, "Date", _formatDate(t['transaction_date'])),
              if (t['description'] != null && (t['description'] as String).isNotEmpty) ...[
                Divider(color: Color(0xFF1A2030), height: 18),
                _metaRow(Icons.notes_rounded, "Description", t['description']),
              ],
              if (t['reference_type'] != null) ...[
                Divider(color: Color(0xFF1A2030), height: 18),
                _metaRow(Icons.link_rounded, "Reference",
                  "${_capitalize(t['reference_type'] ?? '')} #${t['reference_id'] ?? ''}"),
              ],
            ],
          ),
        ),

        // ── Category 1: Product Sales → order items ──────────
        if (catId == 1 && orderItems.isNotEmpty) ...[
          SizedBox(height: 20),
          _sectionLabel("Order Items", "${orderItems.length} items"),
          SizedBox(height: 10),
          ...orderItems.map((item) {
            final product = item['products'] as Map? ?? {};
            final variant = item['product_variants'] as Map?;
            final qty   = double.tryParse(item['quantity'].toString()) ?? 0;
            final price = double.tryParse(item['sell_price'].toString()) ?? 0;
            return _itemRow(
              name: product['name'] ?? '—',
              sub: variant?['name'],
              qty: qty,
              unit: product['unit'],
              price: price,
              color: Color(0xFF10B981),
            );
          }),
        ],

        // ── Category 2: Delivery Fees → just amount + desc ───
        if (catId == 2) ...[
          SizedBox(height: 20),
          _sectionLabel("Delivery Details", null),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFF0F1117),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Color(0xFF0C2A3A), width: 1),
            ),
            child: Row(
              children: [
                Container(width: 38, height: 38,
                  decoration: BoxDecoration(color: Color(0xFF0C2A3A), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.delivery_dining_rounded, color: Color(0xFF06B6D4), size: 18)),
                SizedBox(width: 12),
                Expanded(child: Text(
                  t['description'] ?? 'Delivery fee',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                )),
                Text("Rp ${_formatPrice(amount)}",
                  style: TextStyle(color: Color(0xFF06B6D4), fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],

        // ── Category 3: Product Purchases → transaction_items ─
        if (catId == 3 && txItems.isNotEmpty) ...[
          SizedBox(height: 20),
          _sectionLabel("Purchase Items", "${txItems.length} items"),
          SizedBox(height: 10),
          ...txItems.map((item) {
            final product = item['products'] as Map? ?? {};
            final qty   = double.tryParse((item['quantity'] ?? 1).toString()) ?? 1;
            final price = double.tryParse((item['price'] ?? 0).toString()) ?? 0;
            return _itemRow(
              name: item['description'] ?? product['name'] ?? '—',
              sub: null,
              qty: qty,
              unit: product['unit'],
              price: price,
              color: Color(0xFFF97316),
            );
          }),
          SizedBox(height: 12),
          _totalRow(amount),
        ],

        // Total for order items (cat 1)
        if (catId == 1 && orderItems.isNotEmpty) ...[
          SizedBox(height: 12),
          _totalRow(amount),
        ],
      ],
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Color(0xFF4A5568)),
        SizedBox(width: 8),
        Text("$label  ", style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        Expanded(child: Text(value,
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _sectionLabel(String title, String? count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(
          color: Color(0xFF94A3B8), fontSize: 12,
          fontWeight: FontWeight.w600, letterSpacing: 1.2,
        )),
        if (count != null)
          Text(count, style: TextStyle(color: Color(0xFF4A5568), fontSize: 12)),
      ],
    );
  }

  Widget _itemRow({
    required String name,
    String? sub,
    required double qty,
    String? unit,
    required double price,
    required Color color,
  }) {
    final lineTotal = qty * price;
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Color(0xFF0F1117),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Color(0xFF222840), width: 1),
      ),
      child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              if (sub != null) ...[
                SizedBox(height: 1),
                Text(sub, style: TextStyle(color: Color(0xFF6C63FF), fontSize: 11)),
              ],
              SizedBox(height: 3),
              Text(
                "${qty % 1 == 0 ? qty.toInt() : qty} ${unit ?? ''} × Rp ${_formatPrice(price)}",
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          )),
          Text("Rp ${_formatPrice(lineTotal)}",
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _totalRow(double total) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Color(0xFF0F1117),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFF222840), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Total", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          Text("Rp ${_formatPrice(total)}",
            style: TextStyle(color: Color(0xFFEC4899), fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}