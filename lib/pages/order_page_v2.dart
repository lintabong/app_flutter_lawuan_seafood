import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class OrderPage extends StatefulWidget {
  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  List orders = [];
  bool loading = true;
  bool loadingMore = false;

  // Filters
  DateTime? selectedDate;
  String? selectedStatus;
  final List<String> statuses = ['pending', 'paid', 'prepared', 'picked up', 'delivered', 'cancelled'];

  // Pagination
  int currentPage = 1;
  final int pageSize = 10;
  bool hasMore = true;

  final ScrollController _scrollController = ScrollController();

  static const Color _amber = Color(0xFFF59E0B);
  static const Color _amberBg = Color(0xFF2D1F0A);

  @override
  void initState() {
    super.initState();
    _loadOrders(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!loadingMore && hasMore) _loadMore();
    }
  }

  Future _loadOrders({bool reset = false}) async {
    if (reset) {
      setState(() { loading = true; currentPage = 1; orders = []; hasMore = true; });
    }

    final data = await SupabaseService.getOrders(
      page: 1,
      pageSize: pageSize,
      date: selectedDate,
      status: selectedStatus,
    );

    setState(() {
      orders = data;
      loading = false;
      hasMore = data.length == pageSize;
    });
  }

  Future _loadMore() async {
    if (loadingMore || !hasMore) return;
    setState(() => loadingMore = true);

    final nextPage = currentPage + 1;
    final data = await SupabaseService.getOrders(
      page: nextPage,
      pageSize: pageSize,
      date: selectedDate,
      status: selectedStatus,
    );

    setState(() {
      orders.addAll(data);
      currentPage = nextPage;
      hasMore = data.length == pageSize;
      loadingMore = false;
    });
  }

  Future _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: _amber,
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
      _loadOrders(reset: true);
    }
  }

  void _clearFilters() {
    setState(() {
      selectedDate = null;
      selectedStatus = null;
    });
    _loadOrders(reset: true);
  }

  String _formatDate(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${dt.day} ${months[dt.month - 1]}, ${_pad(dt.hour)}:${_pad(dt.minute)}";
    } catch (_) { return raw; }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

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

  Map<String, dynamic> _statusStyle(String? status) {
    switch (status) {
      case 'pending':    return {'color': Color(0xFFF59E0B), 'bg': Color(0xFF2D1F0A), 'icon': Icons.hourglass_empty_rounded};
      case 'paid':       return {'color': Color(0xFF6C63FF), 'bg': Color(0xFF1E1B4B), 'icon': Icons.check_circle_outline_rounded};
      case 'prepared':   return {'color': Color(0xFF06B6D4), 'bg': Color(0xFF0C2A3A), 'icon': Icons.kitchen_rounded};
      case 'picked up':  return {'color': Color(0xFF8B5CF6), 'bg': Color(0xFF1C1030), 'icon': Icons.directions_bike_rounded};
      case 'delivered':  return {'color': Color(0xFF10B981), 'bg': Color(0xFF062318), 'icon': Icons.task_alt_rounded};
      case 'cancelled':  return {'color': Color(0xFFEF4444), 'bg': Color(0xFF2D0A0A), 'icon': Icons.cancel_outlined};
      default:           return {'color': Color(0xFF94A3B8), 'bg': Color(0xFF1A1F2E), 'icon': Icons.circle_outlined};
    }
  }

  bool get _hasActiveFilters => selectedDate != null || selectedStatus != null;

  // ── Invoice text generator ────────────────────────────────
  // String _buildInvoiceText(Map order) {
  //   final customer = order['customers'] as Map? ?? {};
  //   final phone = customer['phone'] ?? '';
  //   final status = order['status'] ?? '';
  //   final deliveryType = order['delivery_type'] ?? 'pickup';
  //   final typeLabel = deliveryType == 'delivery' ? 'Delivery' : 'In';
  //   final orderId = order['id'];

  //   // We don't have items in the list view, so we'll show a placeholder
  //   // The full invoice with items is built in the detail sheet
  //   final buffer = StringBuffer();
  //   buffer.writeln("Order $orderId - $typeLabel | $phone | $status");
  //   return buffer.toString().trim();
  // }

  // Full invoice text built from order detail data
  String _buildFullInvoiceText(Map<String, dynamic> order) {
    final customer = order['customers'] as Map? ?? {};
    final customerName = customer['name'];
    final phone = customer['phone'] ?? '';
    final status = order['status'] ?? '';
    final orderId = order['id'];
    final items = (order['order_items'] as List?) ?? [];
    final deliveryPrice = double.tryParse(order['delivery_price']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0;
    final lat = customer['latitude'];
    final lng = customer['longitude'];

    final buffer = StringBuffer();
    buffer.writeln("Order $orderId - $customerName | $phone | $status");

    if (lat != null && lng != null) {
      buffer.writeln("https://maps.google.com/maps?q=$lat,$lng");
    }

    for (final item in items) {
      final product = item['products'] as Map? ?? {};
      final variant = item['product_variants'] as Map? ?? {};
      final qty = double.tryParse(item['quantity'].toString()) ?? 0;
      final price = double.tryParse(item['sell_price'].toString()) ?? 0;
      final productNameRaw = product['name'] ?? '-';
      final productName = productNameRaw.replaceAll(RegExp(r'\(.*?\)'), '').trim();
      final variantNameRaw = variant['name'] ?? '';
      final variantName = variantNameRaw.toLowerCase() == 'default' ? '' : "[$variantNameRaw]";
      final unit = variant['unit'] ?? product['unit'] ?? '';
      final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
      final label = variantName.isNotEmpty ? "$productName $variantName" : productName;
      buffer.writeln(" - $label $qtyStr $unit ${_formatPrice(price*qty)}");
    }

    if (deliveryPrice > 0) {
      buffer.writeln("delivery ${_formatPrice(deliveryPrice)}");
    }
    buffer.write("total: ${_formatPrice(total)}");

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F1117),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildFilterBar(context),
            if (_hasActiveFilters) _buildActiveFilters(),
            SizedBox(height: 8),
            Expanded(child: _buildBody()),
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
                Text("Orders", style: TextStyle(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800, letterSpacing: -0.5,
                )),
                if (!loading)
                  Text("${orders.length}${hasMore ? '+' : ''} orders",
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _amberBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withOpacity(0.3), width: 1),
            ),
            child: Icon(Icons.add_rounded, color: _amber, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selectedDate != null ? _amberBg : Color(0xFF161B27),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedDate != null ? _amber.withOpacity(0.4) : Color(0xFF222840),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                      size: 15,
                      color: selectedDate != null ? _amber : Color(0xFF4A5568),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedDate != null
                            ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                            : "Pick date",
                        style: TextStyle(
                          color: selectedDate != null ? _amber : Color(0xFF4A5568),
                          fontSize: 13, fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _showStatusPicker(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selectedStatus != null
                      ? _statusStyle(selectedStatus)['bg']
                      : Color(0xFF161B27),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedStatus != null
                        ? (_statusStyle(selectedStatus)['color'] as Color).withOpacity(0.4)
                        : Color(0xFF222840),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded,
                      size: 15,
                      color: selectedStatus != null
                          ? _statusStyle(selectedStatus)['color']
                          : Color(0xFF4A5568),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedStatus != null
                            ? _capitalize(selectedStatus!)
                            : "Status",
                        style: TextStyle(
                          color: selectedStatus != null
                              ? _statusStyle(selectedStatus)['color']
                              : Color(0xFF4A5568),
                          fontSize: 13, fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          Icon(Icons.filter_list_rounded, size: 13, color: Color(0xFF64748B)),
          SizedBox(width: 6),
          Text("Filters active", style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          Spacer(),
          GestureDetector(
            onTap: _clearFilters,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Color(0xFF2D0A0A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFEF4444).withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, size: 12, color: Color(0xFFEF4444)),
                  SizedBox(width: 4),
                  Text("Clear", style: TextStyle(
                    color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w600,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 36, height: 36,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _amber),
            ),
            SizedBox(height: 16),
            Text("Loading orders...",
              style: TextStyle(color: Color(0xFF4A5568), fontSize: 14)),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, color: Color(0xFF2A3040), size: 64),
            SizedBox(height: 16),
            Text("No orders found",
              style: TextStyle(color: Color(0xFF4A5568), fontSize: 15)),
            if (_hasActiveFilters) ...[
              SizedBox(height: 8),
              GestureDetector(
                onTap: _clearFilters,
                child: Text("Clear filters",
                  style: TextStyle(color: _amber, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: orders.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == orders.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: _amber),
              ),
            ),
          );
        }
        return _buildOrderCard(orders[index], index);
      },
    );
  }

  Widget _buildOrderCard(Map order, int index) {
    final style = _statusStyle(order['status']);
    final color = style['color'] as Color;
    final bg = style['bg'] as Color;
    final icon = style['icon'] as IconData;
    final isDelivery = order['delivery_type'] == 'delivery';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
          splashColor: _amber.withOpacity(0.06),
          onTap: () => _showOrderDetail(context, order['id'], onStatusUpdated: _loadOrders),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "#${order['id']}",
                                style: TextStyle(
                                  color: _amber,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDelivery ? Color(0xFF0C2A3A) : Color(0xFF1E1B4B),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isDelivery ? Icons.delivery_dining_rounded : Icons.storefront_rounded,
                                      size: 10,
                                      color: isDelivery ? Color(0xFF06B6D4) : Color(0xFF6C63FF),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      isDelivery ? "Delivery" : "Pickup",
                                      style: TextStyle(
                                        color: isDelivery ? Color(0xFF06B6D4) : Color(0xFF6C63FF),
                                        fontSize: 10, fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5),
                          Text(
                            order['customers']?['name'] ?? 'Unknown Customer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15, fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.25), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 12, color: color),
                          SizedBox(width: 5),
                          Text(
                            _capitalize(order['status'] ?? ''),
                            style: TextStyle(
                              color: color, fontSize: 11, fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 14),
                Divider(color: Color(0xFF222840), height: 1),
                SizedBox(height: 12),

                // Bottom row: time + copy invoice button + total
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF4A5568)),
                    SizedBox(width: 5),
                    Text(
                      _formatDate(order['order_date']),
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    Spacer(),
                    // Copy invoice button (opens detail to get full data)
                    GestureDetector(
                      onTap: () => _copyInvoiceFromCard(context, order['id']),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1F2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFF2A3040), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 11, color: Color(0xFF64748B)),
                            SizedBox(width: 4),
                            Text("Invoice", style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600,
                            )),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      "Rp ${_formatPrice(order['total_amount'])}",
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 15, fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
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

  Future<void> _copyInvoiceFromCard(BuildContext context, int orderId) async {
    // Show a brief loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text("Building invoice...", style: TextStyle(fontSize: 13)),
          ],
        ),
        backgroundColor: Color(0xFF1E2333),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    try {
      final detail = await SupabaseService.getOrderDetail(orderId);
      final text = _buildFullInvoiceText(detail);
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
              SizedBox(width: 10),
              Text("Invoice copied!", style: TextStyle(fontSize: 13)),
            ],
          ),
          backgroundColor: Color(0xFF1E2333),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to copy invoice", style: TextStyle(fontSize: 13)),
          backgroundColor: Color(0xFF2D0A0A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showOrderDetail(BuildContext context, int orderId, {VoidCallback? onStatusUpdated}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(
        orderId: orderId,
        onStatusUpdated: onStatusUpdated,
        buildInvoiceText: _buildFullInvoiceText,
      ),
    );
  }

  void _showStatusPicker(BuildContext context) {
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
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Color(0xFF2A3040),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Filter by Status", style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
                  )),
                  if (selectedStatus != null)
                    GestureDetector(
                      onTap: () {
                        setState(() => selectedStatus = null);
                        Navigator.pop(context);
                        _loadOrders(reset: true);
                      },
                      child: Text("Clear", style: TextStyle(
                        color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600,
                      )),
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
            ...statuses.map((s) {
              final style = _statusStyle(s);
              final isSelected = selectedStatus == s;
              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: style['bg'],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(style['icon'], color: style['color'], size: 18),
                ),
                title: Text(
                  _capitalize(s),
                  style: TextStyle(
                    color: isSelected ? style['color'] : Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, color: style['color'], size: 18)
                    : null,
                onTap: () {
                  setState(() => selectedStatus = s);
                  Navigator.pop(context);
                  _loadOrders(reset: true);
                },
              );
            }),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ─────────────────────────────────────────────
// Order Detail Bottom Sheet
// ─────────────────────────────────────────────

class _OrderDetailSheet extends StatefulWidget {
  final int orderId;
  final VoidCallback? onStatusUpdated;
  final String Function(Map<String, dynamic>)? buildInvoiceText;

  const _OrderDetailSheet({
    required this.orderId,
    this.onStatusUpdated,
    this.buildInvoiceText,
  });

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  Map<String, dynamic>? order;
  bool loading = true;
  bool updatingStatus = false;

  static const Color _amber = Color(0xFFF59E0B);

  final List<String> _allStatuses = [
    'pending', 'paid', 'prepared', 'picked up', 'delivered', 'cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future _load() async {
    final data = await SupabaseService.getOrderDetail(widget.orderId);
    setState(() { order = data; loading = false; });
  }

  Future _togglePrepared(int itemId, bool current) async {
    await SupabaseService.toggleItemPrepared(itemId, !current);
    final items = order!['order_items'] as List;
    final idx = items.indexWhere((i) => i['id'] == itemId);
    if (idx != -1) {
      setState(() => items[idx]['is_prepared'] = !current);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (updatingStatus) return;
    final currentStatus = order!['status'];
    if (currentStatus == newStatus) return;

    setState(() => updatingStatus = true);

    try {
      await SupabaseService.updateOrderStatusRpc(
        orderId: widget.orderId,
        newStatus: newStatus,
      );
      setState(() {
        order!['status'] = newStatus;
        updatingStatus = false;
      });
      widget.onStatusUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                SizedBox(width: 10),
                Text("Status updated to ${_capitalize(newStatus)}",
                  style: TextStyle(fontSize: 13)),
              ],
            ),
            backgroundColor: Color(0xFF1E2333),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() => updatingStatus = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: ${e.toString().replaceAll('Exception: ', '')}",
              style: TextStyle(fontSize: 12)),
            backgroundColor: Color(0xFF2D0A0A),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showStatusDropdown(BuildContext context) {
    final currentStatus = order!['status'] as String?;
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
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Color(0xFF2A3040),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text("Update Status", style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
              )),
            ),
            SizedBox(height: 16),
            ..._allStatuses.map((s) {
              final style = _statusStyle(s);
              final isSelected = currentStatus == s;
              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: style['bg'],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(style['icon'], color: style['color'], size: 18),
                ),
                title: Text(
                  _capitalize(s),
                  style: TextStyle(
                    color: isSelected ? style['color'] : Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, color: style['color'], size: 18)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(s);
                },
              );
            }),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _copyInvoice(BuildContext context) async {
    if (order == null || widget.buildInvoiceText == null) return;
    final text = widget.buildInvoiceText!(order!);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
            SizedBox(width: 10),
            Text("Invoice copied!", style: TextStyle(fontSize: 13)),
          ],
        ),
        backgroundColor: Color(0xFF1E2333),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year}, ${_pad(dt.hour)}:${_pad(dt.minute)}";
    } catch (_) { return raw; }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Map<String, dynamic> _statusStyle(String? s) {
    switch (s) {
      case 'pending':    return {'color': Color(0xFFF59E0B), 'bg': Color(0xFF2D1F0A), 'icon': Icons.hourglass_empty_rounded};
      case 'paid':       return {'color': Color(0xFF6C63FF), 'bg': Color(0xFF1E1B4B), 'icon': Icons.check_circle_outline_rounded};
      case 'prepared':   return {'color': Color(0xFF06B6D4), 'bg': Color(0xFF0C2A3A), 'icon': Icons.kitchen_rounded};
      case 'picked up':  return {'color': Color(0xFF8B5CF6), 'bg': Color(0xFF1C1030), 'icon': Icons.directions_bike_rounded};
      case 'delivered':  return {'color': Color(0xFF10B981), 'bg': Color(0xFF062318), 'icon': Icons.task_alt_rounded};
      case 'cancelled':  return {'color': Color(0xFFEF4444), 'bg': Color(0xFF2D0A0A), 'icon': Icons.cancel_outlined};
      default:           return {'color': Color(0xFF94A3B8), 'bg': Color(0xFF1A1F2E), 'icon': Icons.circle_outlined};
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Color(0xFF161B27),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Color(0xFF222840), width: 1),
        ),
        child: loading
            ? Center(
                child: SizedBox(
                  width: 32, height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: _amber),
                ),
              )
            : _buildContent(scrollController),
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    final o = order!;
    final customer = o['customers'] as Map? ?? {};
    final items = (o['order_items'] as List?) ?? [];
    final style = _statusStyle(o['status']);
    final statusColor = style['color'] as Color;
    final statusBg = style['bg'] as Color;
    final isDelivery = o['delivery_type'] == 'delivery';

    final subtotal = items.fold<double>(0, (sum, i) {
      return sum + ((double.tryParse(i['sell_price'].toString()) ?? 0) *
          (double.tryParse(i['quantity'].toString()) ?? 0));
    });
    final delivery = double.tryParse(o['delivery_price']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0;

    final preparedCount = items.where((i) => i['is_prepared'] == true).length;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(24, 0, 24, 36),
      children: [
        // Handle
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Color(0xFF2A3040),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),

        // Header: order id + date + copy invoice button
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Order #${o['id']}",
                    style: TextStyle(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w800, letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF4A5568)),
                      SizedBox(width: 5),
                      Text(
                        _formatDate(o['order_date']),
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Copy invoice button
            GestureDetector(
              onTap: () => _copyInvoice(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF1A1F2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Color(0xFF2A3040), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, size: 13, color: Color(0xFF64748B)),
                    SizedBox(width: 5),
                    Text("Invoice", style: TextStyle(
                      color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600,
                    )),
                  ],
                ),
              ),
            ),
            // Status badge — tappable dropdown
            GestureDetector(
              onTap: updatingStatus ? null : () => _showStatusDropdown(context),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withOpacity(0.25), width: 1),
                ),
                child: updatingStatus
                    ? SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: statusColor),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(style['icon'], size: 13, color: statusColor),
                          SizedBox(width: 6),
                          Text(
                            _capitalize(o['status'] ?? ''),
                            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.expand_more_rounded, size: 13, color: statusColor.withOpacity(0.7)),
                        ],
                      ),
              ),
            ),
          ],
        ),

        SizedBox(height: 20),

        // Customer card
        Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Color(0xFF0F1117),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFF222840), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF0C2A3A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_rounded, color: Color(0xFF06B6D4), size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer['name'] ?? 'Unknown',
                      style: TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (customer['phone'] != null) ...[
                      SizedBox(height: 2),
                      Text(customer['phone'], style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDelivery ? Color(0xFF0C2A3A) : Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDelivery ? Icons.delivery_dining_rounded : Icons.storefront_rounded,
                      size: 12,
                      color: isDelivery ? Color(0xFF06B6D4) : Color(0xFF6C63FF),
                    ),
                    SizedBox(width: 5),
                    Text(
                      isDelivery ? "Delivery" : "Pickup",
                      style: TextStyle(
                        color: isDelivery ? Color(0xFF06B6D4) : Color(0xFF6C63FF),
                        fontSize: 11, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 20),

        // Items header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Items",
              style: TextStyle(
                color: Color(0xFF94A3B8), fontSize: 12,
                fontWeight: FontWeight.w600, letterSpacing: 1.2,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: preparedCount == items.length && items.isNotEmpty
                    ? Color(0xFF062318) : Color(0xFF2D1F0A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "$preparedCount / ${items.length} prepared",
                style: TextStyle(
                  color: preparedCount == items.length && items.isNotEmpty
                      ? Color(0xFF10B981) : _amber,
                  fontSize: 11, fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 10),

        // Items list
        ...items.map((item) {
          final product = item['products'] as Map? ?? {};
          final variant = item['product_variants'] as Map? ?? {};
          final isPrepared = item['is_prepared'] == true;
          final qty = double.tryParse(item['quantity'].toString()) ?? 0;
          final price = double.tryParse(item['sell_price'].toString()) ?? 0;
          final lineTotal = qty * price;

          return Container(
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFF0F1117),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPrepared ? Color(0xFF10B981).withOpacity(0.2) : Color(0xFF222840),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _togglePrepared(item['id'], isPrepared),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: isPrepared ? Color(0xFF10B981) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPrepared ? Color(0xFF10B981) : Color(0xFF2A3040),
                        width: 1.5,
                      ),
                    ),
                    child: isPrepared
                        ? Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : null,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] ?? '-',
                        style: TextStyle(
                          color: isPrepared ? Color(0xFF4A5568) : Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w600,
                          decoration: isPrepared ? TextDecoration.lineThrough : null,
                          decorationColor: Color(0xFF4A5568),
                        ),
                      ),
                      if (variant.isNotEmpty && variant['name'] != null) ...[
                        SizedBox(height: 2),
                        Text(
                          variant['name'] ?? '',
                          style: TextStyle(color: Color(0xFF6C63FF), fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                      SizedBox(height: 4),
                      Text(
                        "${qty % 1 == 0 ? qty.toInt() : qty} ${variant['unit'] ?? ''} × Rp ${_formatPrice(price)}",
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  "Rp ${_formatPrice(lineTotal)}",
                  style: TextStyle(
                    color: isPrepared ? Color(0xFF4A5568) : Color(0xFF10B981),
                    fontSize: 13, fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }),

        SizedBox(height: 8),

        // Price summary
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF0F1117),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFF222840), width: 1),
          ),
          child: Column(
            children: [
              _summaryRow("Subtotal", "Rp ${_formatPrice(subtotal)}",
                  valueColor: Colors.white),
              if (isDelivery) ...[
                SizedBox(height: 10),
                _summaryRow("Delivery fee", "Rp ${_formatPrice(delivery)}",
                    valueColor: Color(0xFF06B6D4)),
              ],
              SizedBox(height: 12),
              Divider(color: Color(0xFF222840), height: 1),
              SizedBox(height: 12),
              _summaryRow(
                "Total",
                "Rp ${_formatPrice(total)}",
                labelStyle: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                valueColor: _amber,
                valueFontSize: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {
    Color valueColor = Colors.white,
    TextStyle? labelStyle,
    double valueFontSize = 13,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle ?? TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(value, style: TextStyle(
          color: valueColor, fontSize: valueFontSize, fontWeight: FontWeight.w700,
        )),
      ],
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}