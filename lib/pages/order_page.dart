import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

import '../helpers/currency_utils.dart';
import '../helpers/date_utils.dart' as AppDateUtils;
import '../helpers/status_utils.dart';
import '../helpers/text_utils.dart';
import '../constants.dart';

class OrderPage extends StatefulWidget {
  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  List orders = [];
  bool loading = true;

  // Filters
  DateTime? selectedDate;          // null = no date filter
  String? selectedStatus;
  String _nameQuery = '';
  final TextEditingController _nameController = TextEditingController();

  // Pagination
  int _page = 1;
  static const int _pageSize = 10;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  int? selectedOrderIndex;
  final Set<int> _updatingItems  = {};
  final Set<int> _updatingOrders = {};

  static const Color _cyan   = AppColors.cyan;
  static const Color _cyanBg = AppColors.cyanBg;
  static const Color _amber  = AppColors.amber;

  static const List<String> _statuses = [
    'pending', 'prepared', 'paid', 'delivered', 'cancelled',
  ];

  bool _requiresRpc(String from, String to) {
    const triggers = {'pending', 'prepared'};
    const targets  = {'paid', 'delivered'};
    return triggers.contains(from) && targets.contains(to);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  // Full reload (page 1) — called when filters change
  Future _load() async {
    setState(() {
      loading = true;
      selectedOrderIndex = null;
      _page = 1;
      _hasMore = true;
      orders = [];
    });
    final data = await SupabaseService.getOrders(
      page:     1,
      pageSize: _pageSize,
      date:     selectedDate,
      status:   selectedStatus,
      name:     _nameQuery.isNotEmpty ? _nameQuery : null,
      withItems: true,
    );
    setState(() {
      orders  = data;
      loading = false;
      _hasMore = data.length == _pageSize;
    });
  }

  // Append next page
  Future _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final data = await SupabaseService.getOrders(
      page:     nextPage,
      pageSize: _pageSize,
      date:     selectedDate,
      status:   selectedStatus,
      name:     _nameQuery.isNotEmpty ? _nameQuery : null,
      withItems: true,
    );
    setState(() {
      _page       = nextPage;
      _loadingMore = false;
      _hasMore    = data.length == _pageSize;
      orders.addAll(data);
    });
  }

  Future _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: _cyan,
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

  // ── Item toggle ──────────────────────────────────────────
  Future _toggleItem(int oi, int ii) async {
    final item    = orders[oi]['order_items'][ii];
    final itemId  = item['id'] as int;
    final current = item['is_prepared'] == true;
    if (_updatingItems.contains(itemId)) return;
    setState(() => _updatingItems.add(itemId));
    try {
      await SupabaseService.toggleItemPrepared(itemId, !current);
      setState(() => orders[oi]['order_items'][ii]['is_prepared'] = !current);
    } finally {
      setState(() => _updatingItems.remove(itemId));
    }
  }

  Future _changeStatus(BuildContext context, int oi, String newStatus) async {
    final order     = orders[oi];
    final orderId   = order['id'] as int;
    final oldStatus = order['status'] as String;
    if (oldStatus == newStatus || _updatingOrders.contains(orderId)) return;
    setState(() => _updatingOrders.add(orderId));
    try {
      await SupabaseService.updateOrderStatusRpc(
        orderId: orderId, newStatus: newStatus);
      setState(() => orders[oi]['status'] = newStatus);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: const Color(0xFF2D0A0A),
        ));
      }
    } finally {
      setState(() => _updatingOrders.remove(orderId));
    }
  }

  void _showStatusPicker(BuildContext context, int oi) {
    final current = orders[oi]['status'] as String;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Color(0xFF161B27),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Color(0xFF222840), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12),
            Container(width: 36, height: 4,
              decoration: BoxDecoration(
                color: Color(0xFF2A3040),
                borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 18),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text("Update Status", style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            SizedBox(height: 12),
            ..._statuses.map((s) {
              final st        = StatusUtils.statusStyle(s);
              final color     = st['color'] as Color;
              final isCurrent = s == current;
              final needsRpc  = _requiresRpc(current, s);
              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: st['bg'], borderRadius: BorderRadius.circular(10)),
                  child: Icon(st['icon'], color: color, size: 18),
                ),
                title: Text(TextUtils.capitalize(s), style: TextStyle(
                  color: isCurrent ? color : Colors.white,
                  fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: needsRpc
                    ? Row(children: [
                        Icon(Icons.bolt_rounded, size: 11, color: Color(0xFF10B981)),
                        SizedBox(width: 3),
                        Text("Applies cash inflow",
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
                      ])
                    : null,
                trailing: isCurrent
                    ? Icon(Icons.check_rounded, color: color, size: 18)
                    : null,
                onTap: isCurrent ? null : () {
                  Navigator.pop(context);
                  _changeStatus(context, oi, s);
                },
              );
            }),
            SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F1117),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(
            child: loading
                ? Center(child: SizedBox(width: 32, height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: _cyan)))
                : orders.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delivery_dining_outlined,
                            color: Color(0xFF2A3040), size: 52),
                          SizedBox(height: 12),
                          Text("No orders found",
                            style: TextStyle(color: Color(0xFF4A5568), fontSize: 14)),
                        ],
                      ))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: orders.length + (_hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == orders.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: SizedBox(width: 24, height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _cyan))),
                            );
                          }
                          return _buildCard(ctx, i);
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  // ── Invoice ──────────────────────────────────────────────
  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num = (double.tryParse(price.toString()) ?? 0).round();
    final str = num.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _buildFullInvoiceText(Map<String, dynamic> order) {
    final customer     = order['customers'] as Map? ?? {};
    final customerName = customer['name'];
    final phone        = customer['phone'] ?? '';
    final status       = order['status'] ?? '';
    final orderId      = order['id'];
    final items        = (order['order_items'] as List?) ?? [];
    final deliveryPrice = double.tryParse(order['delivery_price']?.toString() ?? '0') ?? 0;
    final total         = double.tryParse(order['total_amount']?.toString()   ?? '0') ?? 0;
    final lat  = customer['latitude'];
    final lng  = customer['longitude'];

    final buffer = StringBuffer();
    buffer.writeln("Order $orderId - $customerName | $phone | $status");

    if (lat != null && lng != null) {
      buffer.writeln("https://maps.google.com/maps?q=$lat,$lng");
    }

    for (final item in items) {
      final product        = item['products'] as Map? ?? {};
      final variant        = item['product_variants'] as Map? ?? {};
      final qty            = double.tryParse(item['quantity'].toString()) ?? 0;
      final price          = double.tryParse(item['sell_price'].toString()) ?? 0;
      final productNameRaw = product['name'] ?? '-';
      final productName    = productNameRaw.replaceAll(RegExp(r'\(.*?\)'), '').trim();
      final variantNameRaw = variant['name'] ?? '';
      final variantName    = variantNameRaw.toLowerCase() == 'default' ? '' : "[$variantNameRaw]";
      final unit           = variant['unit'] ?? product['unit'] ?? '';
      final qtyStr         = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
      final label          = variantName.isNotEmpty ? "$productName $variantName" : productName;
      buffer.writeln(" - $label $qtyStr $unit ${_formatPrice(price * qty)}");
    }

    if (deliveryPrice > 0) {
      buffer.writeln("delivery ${_formatPrice(deliveryPrice)}");
    }
    buffer.write("total: ${_formatPrice(total)}");

    return buffer.toString();
  }

  Future<void> _copyInvoice(BuildContext context, Map order) async {
    final text = _buildFullInvoiceText(Map<String, dynamic>.from(order));
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
          SizedBox(width: 10),
          Text("Invoice copied!", style: TextStyle(fontSize: 13)),
        ]),
        backgroundColor: Color(0xFF1E2333),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Header (back button + title) ─────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFF1E2333),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF2A3040), width: 1),
              ),
              child: Icon(Icons.arrow_back_rounded,
                color: Color(0xFF94A3B8), size: 20),
            ),
          ),
          SizedBox(width: 16),
          // Title + count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Orders",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (!loading)
                  Text(
                    "${orders.length} orders",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final bool hasDate   = selectedDate != null;
    final bool hasStatus = selectedStatus != null;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
      color: Color(0xFF0F1117),
      child: Column(children: [
        // Search by name
        Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Color(0xFF161B27),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFF222840), width: 1),
          ),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 16, color: Color(0xFF4A5568)),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _nameController,
                style: TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by customer name…',
                  hintStyle: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) {
                  _nameQuery = v;
                  Future.delayed(Duration(milliseconds: 400), () {
                    if (_nameQuery == v) _load();
                  });
                },
              ),
            ),
            if (_nameQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _nameController.clear();
                  _nameQuery = '';
                  _load();
                },
                child: Icon(Icons.close_rounded, size: 15, color: Color(0xFF4A5568)),
              ),
          ]),
        ),

        SizedBox(height: 8),

        // Date + Status chips
        Row(children: [
          // Date chip
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                height: 36,
                padding: EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: hasDate ? _cyanBg : Color(0xFF161B27),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasDate ? _cyan.withOpacity(0.4) : Color(0xFF222840),
                    width: 1),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded,
                    size: 13, color: hasDate ? _cyan : Color(0xFF4A5568)),
                  SizedBox(width: 6),
                  Expanded(child: Text(
                    hasDate
                        ? AppDateUtils.DateUtils.formatFullDate(selectedDate!)
                        : 'All dates',
                    style: TextStyle(
                      color: hasDate ? _cyan : Color(0xFF4A5568),
                      fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  )),
                  if (hasDate)
                    GestureDetector(
                      onTap: () { setState(() => selectedDate = null); _load(); },
                      child: Icon(Icons.close_rounded, size: 13, color: _cyan),
                    ),
                ]),
              ),
            ),
          ),

          SizedBox(width: 8),

          // Status chip
          Expanded(
            child: GestureDetector(
              onTap: () => _showFilterStatusPicker(context),
              child: Container(
                height: 36,
                padding: EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: hasStatus
                      ? (StatusUtils.statusStyle(selectedStatus!)['bg'] as Color)
                      : Color(0xFF161B27),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasStatus
                        ? (StatusUtils.statusStyle(selectedStatus!)['color'] as Color)
                            .withOpacity(0.4)
                        : Color(0xFF222840),
                    width: 1),
                ),
                child: Row(children: [
                  Icon(
                    hasStatus
                        ? (StatusUtils.statusStyle(selectedStatus!)['icon'] as IconData)
                        : Icons.filter_list_rounded,
                    size: 13,
                    color: hasStatus
                        ? (StatusUtils.statusStyle(selectedStatus!)['color'] as Color)
                        : Color(0xFF4A5568),
                  ),
                  SizedBox(width: 6),
                  Expanded(child: Text(
                    hasStatus ? TextUtils.capitalize(selectedStatus!) : 'All statuses',
                    style: TextStyle(
                      color: hasStatus
                          ? (StatusUtils.statusStyle(selectedStatus!)['color'] as Color)
                          : Color(0xFF4A5568),
                      fontSize: 11, fontWeight: FontWeight.w600),
                  )),
                  if (hasStatus)
                    GestureDetector(
                      onTap: () { setState(() => selectedStatus = null); _load(); },
                      child: Icon(Icons.close_rounded, size: 13,
                        color: StatusUtils.statusStyle(selectedStatus!)['color'] as Color),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  void _showFilterStatusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Color(0xFF161B27),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Color(0xFF222840), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12),
            Container(width: 36, height: 4,
              decoration: BoxDecoration(
                color: Color(0xFF2A3040),
                borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 18),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text("Filter by Status", style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 2),
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF1A2035),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.all_inclusive_rounded,
                  color: Color(0xFF64748B), size: 18),
              ),
              title: Text("All statuses", style: TextStyle(
                color: selectedStatus == null ? Colors.white : Color(0xFF64748B),
                fontSize: 14, fontWeight: FontWeight.w600)),
              trailing: selectedStatus == null
                  ? Icon(Icons.check_rounded, color: _cyan, size: 18)
                  : null,
              onTap: () {
                Navigator.pop(context);
                setState(() => selectedStatus = null);
                _load();
              },
            ),
            ..._statuses.map((s) {
              final st        = StatusUtils.statusStyle(s);
              final color     = st['color'] as Color;
              final isCurrent = s == selectedStatus;
              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: st['bg'], borderRadius: BorderRadius.circular(10)),
                  child: Icon(st['icon'], color: color, size: 18),
                ),
                title: Text(TextUtils.capitalize(s), style: TextStyle(
                  color: isCurrent ? color : Colors.white,
                  fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: isCurrent
                    ? Icon(Icons.check_rounded, color: color, size: 18)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => selectedStatus = s);
                  _load();
                },
              );
            }),
            SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, int oi) {
    final o          = orders[oi];
    final orderId    = o['id'] as int;
    final orderDate  = DateTime.tryParse(o['order_date']?.toString() ?? '');
    final orderLocal = orderDate?.toLocal();

    // Full date string: e.g. "17 Mar 2025, 14:30"
    final orderDateLabel = orderLocal != null
        ? AppDateUtils.DateUtils.formatFullDate(orderLocal)
        : '—';
    final orderTimeLabel = orderLocal != null
        ? "${orderLocal.hour.toString().padLeft(2, '0')}:${orderLocal.minute.toString().padLeft(2, '0')}"
        : '--:--';

    final customer   = o['customers'] as Map? ?? {};
    final items      = (o['order_items'] as List?) ?? [];
    final isSelected = selectedOrderIndex == oi;
    final isUpdating = _updatingOrders.contains(orderId);
    final st         = StatusUtils.statusStyle(o['status']);
    final statusColor = st['color'] as Color;
    final hasCoords   = double.tryParse(customer['latitude']?.toString() ?? '') != null;
    final total    = double.tryParse(o['total_amount']?.toString()   ?? '0') ?? 0;
    final delivery = double.tryParse(o['delivery_price']?.toString() ?? '0') ?? 0;
    final subtotal = total - delivery;

    return GestureDetector(
      onTap: () {
        final was = selectedOrderIndex == oi;
        setState(() => selectedOrderIndex = was ? null : oi);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Color(0xFF161B27),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _cyan.withOpacity(0.5) : Color(0xFF222840),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _cyan.withOpacity(0.1), blurRadius: 16, offset: Offset(0, 4))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: isSelected ? _cyanBg : Color(0xFF0F1117),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delivery_dining_rounded,
                      color: isSelected ? _cyan : Color(0xFF4A5568), size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order ID + "On map" badge
                        Row(children: [
                          Text("#$orderId", style: TextStyle(
                            color: _amber, fontSize: 12, fontWeight: FontWeight.w700)),
                          SizedBox(width: 6),
                          if (hasCoords) Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _cyanBg,
                              borderRadius: BorderRadius.circular(5)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.location_on_rounded, size: 9, color: _cyan),
                              SizedBox(width: 3),
                              Text("On map", style: TextStyle(
                                color: _cyan, fontSize: 9, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ]),
                        SizedBox(height: 3),
                        Text(customer['name'] ?? 'Unknown', style: TextStyle(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                        SizedBox(height: 4),
                        // Date + time row
                        Row(children: [
                          Icon(Icons.access_time_rounded,
                            size: 11, color: Color(0xFF4A5568)),
                          SizedBox(width: 4),
                          Text("$orderDateLabel · $orderTimeLabel",
                            style: TextStyle(
                              color: Color(0xFF4A5568),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            )),
                        ]),
                        SizedBox(height: 2),
                        Text(customer['address'] ?? customer['phone'] ?? '—',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        SizedBox(height: 6),
                        // Total on card
                        Text(
                          "Rp ${_formatPrice(total)}",
                          style: TextStyle(
                            color: _amber,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  // Right column: status + invoice + expand
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status badge
                      GestureDetector(
                        onTap: () => _showStatusPicker(context, oi),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: st['bg'],
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                          ),
                          child: isUpdating
                              ? SizedBox(
                                  width: 58, height: 14,
                                  child: Center(child: SizedBox(width: 12, height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: statusColor))))
                              : Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(st['icon'], size: 11, color: statusColor),
                                  SizedBox(width: 4),
                                  Text(TextUtils.capitalize(o['status'] ?? ''), style: TextStyle(
                                    color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                                  SizedBox(width: 3),
                                  Icon(Icons.expand_more_rounded, size: 12,
                                    color: statusColor.withOpacity(0.7)),
                                ]),
                        ),
                      ),
                      SizedBox(height: 6),
                      // Invoice copy button
                      GestureDetector(
                        onTap: () => _copyInvoice(context, o),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF1A2035),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: Color(0xFF2A3040), width: 1),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.receipt_long_rounded,
                              size: 11, color: Color(0xFF94A3B8)),
                            SizedBox(width: 4),
                            Text("Invoice", style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            )),
                          ]),
                        ),
                      ),
                      SizedBox(height: 6),
                      AnimatedRotation(
                        turns: isSelected ? 0.5 : 0,
                        duration: Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF4A5568), size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            AnimatedCrossFade(
              firstChild: SizedBox.shrink(),
              secondChild: _buildExpanded(context, oi, items, subtotal, delivery, total),
              crossFadeState: isSelected ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(
    BuildContext context, int oi, List items,
    double subtotal, double delivery, double total,
  ) {
    return Column(children: [
      Divider(color: Color(0xFF222840), height: 1, indent: 14, endIndent: 14),

      if (items.isNotEmpty) ...[
        Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ITEMS", style: TextStyle(
                color: Color(0xFF4A5568), fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              Text("${items.where((i) => i['is_prepared'] == true).length}/${items.length} prepared",
                style: TextStyle(
                  color: items.every((i) => i['is_prepared'] == true)
                      ? Color(0xFF10B981) : Color(0xFF4A5568),
                  fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        ...List.generate(items.length, (ii) {
          final item       = items[ii];
          final itemId     = item['id'] as int;
          final product    = item['products'] as Map? ?? {};
          final variant    = item['product_variants'] as Map?;
          final qty        = double.tryParse(item['quantity'].toString()) ?? 0;
          final price      = double.tryParse(item['sell_price'].toString()) ?? 0;
          final isPrepared = item['is_prepared'] == true;
          final isLoading  = _updatingItems.contains(itemId);

          return GestureDetector(
            onTap: () => _toggleItem(oi, ii),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: isPrepared ? Color(0xFF062318) : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: isPrepared ? Color(0xFF10B981) : Color(0xFF2A3040),
                      width: 1.5),
                  ),
                  child: isLoading
                      ? Padding(padding: EdgeInsets.all(4),
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF10B981)))
                      : isPrepared
                          ? Icon(Icons.check_rounded, size: 14, color: Color(0xFF10B981))
                          : null,
                ),
                SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['name'] ?? '—', style: TextStyle(
                      color: isPrepared ? Color(0xFF4A5568) : Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w600,
                      decoration: isPrepared ? TextDecoration.lineThrough : null,
                      decorationColor: Color(0xFF4A5568),
                    )),
                    if (variant != null)
                      Text(variant['name'] ?? '',
                        style: TextStyle(color: Color(0xFF6C63FF), fontSize: 10)),
                  ],
                )),
                Text("${qty % 1 == 0 ? qty.toInt() : qty} ${product['unit'] ?? ''}",
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                SizedBox(width: 12),
                Text("Rp ${CurrencyUtils.formatPrice(qty * price)}", style: TextStyle(
                  color: isPrepared ? Color(0xFF4A5568) : Color(0xFF10B981),
                  fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          );
        }),
      ],

      Container(
        margin: EdgeInsets.fromLTRB(14, 4, 14, 14),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF0F1117),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF222840), width: 1),
        ),
        child: Column(children: [
          _totalRow("Subtotal",     subtotal, Color(0xFFCBD5E1)),
          SizedBox(height: 8),
          _totalRow("Delivery fee", delivery, _cyan),
          Padding(padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFF222840), height: 1)),
          _totalRow("Total", total, _amber, large: true),
        ]),
      ),
    ]);
  }

  Widget _totalRow(String label, double amount, Color valueColor, {bool large = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          color: large ? Colors.white : Color(0xFF64748B),
          fontSize: large ? 14 : 12,
          fontWeight: large ? FontWeight.w800 : FontWeight.w500)),
        Text("Rp ${CurrencyUtils.formatPrice(amount)}", style: TextStyle(
          color: valueColor, fontSize: large ? 15 : 12, fontWeight: FontWeight.w800)),
      ],
    );
  }
}