
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/supabase_service.dart';

class DeliveryOrderPage extends StatefulWidget {
  @override
  State<DeliveryOrderPage> createState() => _DeliveryOrderPageState();
}

class _DeliveryOrderPageState extends State<DeliveryOrderPage> {
  List orders = [];
  bool loading = true;
  DateTime selectedDate = DateTime.now();
  int? selectedOrderIndex;

  final Set<int> _updatingItems  = {};
  final Set<int> _updatingOrders = {};

  final MapController _mapController = MapController();

  static const LatLng _depot  = LatLng(-7.586647230136144, 110.94508655273896);
  static const Color  _cyan   = Color(0xFF06B6D4);
  static const Color  _cyanBg = Color(0xFF0C2A3A);
  static const Color  _amber  = Color(0xFFF59E0B);

  static const List<String> _statuses = [
    'pending', 'prepared', 'paid', 'delivered', 'cancelled',
  ];

  // Transitions that need the cash-inflow RPC
  bool _requiresRpc(String from, String to) {
    const triggers = {'pending', 'prepared'};
    const targets  = {'paid', 'delivered'};
    return triggers.contains(from) && targets.contains(to);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future _load() async {
    setState(() { loading = true; selectedOrderIndex = null; });
    final data = await SupabaseService.getOrders(
      date: selectedDate,
      deliveryType: 'delivery',
      withItems: true,
      pageSize: 100,
    );
    setState(() { orders = data; loading = false; });
    if (orders.isNotEmpty) {
      final first = _firstWithCoords();
      if (first != null) {
        Future.delayed(Duration(milliseconds: 400), () {
          if (mounted) _mapController.move(first, 13);
        });
      }
    }
  }

  LatLng? _firstWithCoords() {
    for (final o in orders) {
      final c   = o['customers'];
      final lat = double.tryParse(c?['latitude']?.toString()  ?? '');
      final lng = double.tryParse(c?['longitude']?.toString() ?? '');
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  void _flyTo(Map order) {
    final c   = order['customers'];
    final lat = double.tryParse(c?['latitude']?.toString()  ?? '');
    final lng = double.tryParse(c?['longitude']?.toString() ?? '');
    if (lat != null && lng != null) _mapController.move(LatLng(lat, lng), 15);
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
        orderId:   orderId,
        newStatus: newStatus,
      );
      setState(() => orders[oi]['status'] = newStatus);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Failed to update: $e'),
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
              decoration: BoxDecoration(color: Color(0xFF2A3040), borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 18),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text("Update Status", style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            SizedBox(height: 12),
            ..._statuses.map((s) {
              final st        = _statusStyle(s);
              final color     = st['color'] as Color;
              final isCurrent = s == current;
              final needsRpc  = _requiresRpc(current, s);
              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: st['bg'], borderRadius: BorderRadius.circular(10)),
                  child: Icon(st['icon'], color: color, size: 18),
                ),
                title: Text(_capitalize(s), style: TextStyle(
                  color: isCurrent ? color : Colors.white,
                  fontSize: 14, fontWeight: FontWeight.w600,
                )),
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

  // ── Date picker ──────────────────────────────────────────

  Future _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2200),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: _cyan, surface: Color(0xFF161B27), onSurface: Colors.white),
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

  // ── Helpers ──────────────────────────────────────────────

  String _formatPrice(dynamic p) {
    if (p == null) return '0';
    final n   = double.tryParse(p.toString()) ?? 0;
    final str = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  String _formatFullDate(DateTime d) {
    const m = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return "${d.day} ${m[d.month - 1]} ${d.year}";
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Map<String, dynamic> _statusStyle(String? s) {
    switch (s) {
      case 'pending':   return {'color': Color(0xFFF59E0B), 'bg': Color(0xFF2D1F0A), 'icon': Icons.hourglass_empty_rounded};
      case 'prepared':  return {'color': Color(0xFF06B6D4), 'bg': Color(0xFF0C2A3A), 'icon': Icons.kitchen_rounded};
      case 'paid':      return {'color': Color(0xFF6C63FF), 'bg': Color(0xFF1E1B4B), 'icon': Icons.payments_rounded};
      case 'delivered': return {'color': Color(0xFF10B981), 'bg': Color(0xFF062318), 'icon': Icons.task_alt_rounded};
      case 'cancelled': return {'color': Color(0xFFEF4444), 'bg': Color(0xFF2D0A0A), 'icon': Icons.cancel_outlined};
      default:          return {'color': Color(0xFF94A3B8), 'bg': Color(0xFF1A1F2E), 'icon': Icons.circle_outlined};
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Map markers ──────────────────────────────────────────

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Depot
    markers.add(Marker(
      point: _depot,
      width: 48, height: 58,
      child: Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Color(0xFF2D1200), shape: BoxShape.circle,
            border: Border.all(color: Color(0xFFF97316), width: 2),
            boxShadow: [BoxShadow(color: Color(0xFFF97316).withOpacity(0.4), blurRadius: 12)],
          ),
          child: Icon(Icons.store_rounded, color: Color(0xFFF97316), size: 18),
        ),
        Container(width: 2, height: 12,
          decoration: BoxDecoration(color: Color(0xFFF97316), borderRadius: BorderRadius.circular(1))),
        Container(width: 6, height: 6,
          decoration: BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle)),
      ]),
    ));

    // Orders
    for (int i = 0; i < orders.length; i++) {
      final o   = orders[i];
      final c   = o['customers'];
      final lat = double.tryParse(c?['latitude']?.toString()  ?? '');
      final lng = double.tryParse(c?['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      final isSelected = selectedOrderIndex == i;
      final dotColor   = isSelected ? _cyan : (_statusStyle(o['status'])['color'] as Color);

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: isSelected ? 56 : 40,
        height: isSelected ? 66 : 50,
        child: GestureDetector(
          onTap: () {
            setState(() => selectedOrderIndex = selectedOrderIndex == i ? null : i);
            if (selectedOrderIndex == i) _flyTo(o);
          },
          child: Column(children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: isSelected ? 44 : 32, height: isSelected ? 44 : 32,
              decoration: BoxDecoration(
                color: isSelected ? _cyanBg : Color(0xFF161B27),
                shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: isSelected ? 2.5 : 1.5),
                boxShadow: [BoxShadow(
                  color: dotColor.withOpacity(isSelected ? 0.5 : 0.2),
                  blurRadius: isSelected ? 16 : 6)],
              ),
              child: Icon(Icons.delivery_dining_rounded, color: dotColor, size: isSelected ? 22 : 16),
            ),
            Container(
              width: isSelected ? 3 : 2, height: isSelected ? 14 : 10,
              decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(1))),
            Container(
              width: isSelected ? 8 : 6, height: isSelected ? 8 : 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          ]),
        ),
      ));
    }
    return markers;
  }

  // ── Root build ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F1117),
      body: SafeArea(
        child: Column(children: [
          // MAP
          Expanded(
            flex: 5,
            child: Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _depot,
                    initialZoom: 12,
                    interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'app_flutter_lawuan_seafood',
                      maxZoom: 19,
                      tileBuilder: (ctx, tile, _) => ColorFiltered(
                        colorFilter: ColorFilter.matrix([
                          0.30, 0.0, 0.0, 0, 20,
                          0.00, 0.3, 0.0, 0, 20,
                          0.00, 0.0, 0.4, 0, 30,
                          0.00, 0.0, 0.0, 1,  0,
                        ]),
                        child: tile,
                      ),
                    ),
                    MarkerLayer(markers: _buildMarkers()),
                  ],
                ),
              ),

              // Back button
              Positioned(top: 16, left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xE6161B27), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF2A3040), width: 1),
                    ),
                    child: Icon(Icons.arrow_back_rounded, color: Color(0xFF94A3B8), size: 20),
                  ),
                ),
              ),

              // Title overlay
              Positioned(top: 16, left: 68, right: 16,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Color(0xE6161B27), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFF2A3040), width: 1),
                  ),
                  child: Row(children: [
                    Icon(Icons.delivery_dining_rounded, color: _cyan, size: 16),
                    SizedBox(width: 8),
                    Text("Delivery Orders", style: TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    Spacer(),
                    Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle)),
                    SizedBox(width: 5),
                    Text("Depot", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    SizedBox(width: 10),
                    if (!loading)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _cyanBg, borderRadius: BorderRadius.circular(7)),
                        child: Text("${orders.length}",
                          style: TextStyle(color: _cyan, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ),
              ),

              // OSM attribution
              Positioned(bottom: 28, right: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Color(0xAA000000), borderRadius: BorderRadius.circular(4)),
                  child: Text("© OpenStreetMap contributors", style: TextStyle(color: Colors.white70, fontSize: 9)),
                ),
              ),
            ]),
          ),

          // LIST
          Expanded(
            flex: 6,
            child: Column(children: [
              // Date bar
              Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: GestureDetector(
                  onTap: () => _pickDate(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Color(0xFF161B27), borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Color(0xFF222840), width: 1),
                    ),
                    child: Row(children: [
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(color: _cyanBg, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.calendar_today_rounded, size: 14, color: _cyan),
                      ),
                      SizedBox(width: 10),
                      Expanded(child: Text(
                        _isToday(selectedDate)
                            ? "Today — ${_formatFullDate(selectedDate)}"
                            : _formatFullDate(selectedDate),
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      )),
                      Icon(Icons.expand_more_rounded, color: Color(0xFF4A5568), size: 18),
                    ]),
                  ),
                ),
              ),

              Expanded(
                child: loading
                    ? Center(child: SizedBox(width: 32, height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: _cyan)))
                    : orders.isEmpty
                        ? Center(child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delivery_dining_outlined, color: Color(0xFF2A3040), size: 52),
                              SizedBox(height: 12),
                              Text("No deliveries on this date",
                                style: TextStyle(color: Color(0xFF4A5568), fontSize: 14)),
                            ],
                          ))
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: orders.length,
                            itemBuilder: (ctx, i) => _buildCard(ctx, i),
                          ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Card ─────────────────────────────────────────────────
  Widget _buildCard(BuildContext context, int oi) {
    final o          = orders[oi];
    final orderId    = o['id'] as int;
    final orderDate = DateTime.tryParse(o['order_date']?.toString() ?? '');
    final orderTime = orderDate != null
        ? "${orderDate.toLocal().hour.toString().padLeft(2, '0')}:${orderDate.toLocal().minute.toString().padLeft(2, '0')}"
        : "--:--";
    final customer   = o['customers'] as Map? ?? {};
    final items      = (o['order_items'] as List?) ?? [];
    final isSelected = selectedOrderIndex == oi;
    final isUpdating = _updatingOrders.contains(orderId);
    final st         = _statusStyle(o['status']);
    final statusColor = st['color'] as Color;
    final hasCoords   = double.tryParse(customer['latitude']?.toString() ?? '') != null;
    final total    = double.tryParse(o['total_amount']?.toString()   ?? '0') ?? 0;
    final delivery = double.tryParse(o['delivery_price']?.toString() ?? '0') ?? 0;
    final subtotal = total - delivery;

    return GestureDetector(
      onTap: () {
        final was = selectedOrderIndex == oi;
        setState(() => selectedOrderIndex = was ? null : oi);
        if (!was) _flyTo(o);
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
                        Row(children: [
                          Text("#$orderId", style: TextStyle(
                            color: _amber, fontSize: 12, fontWeight: FontWeight.w700)),
                          SizedBox(width: 6),
                          Text(orderTime, style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          )),
                          if (hasCoords) Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: _cyanBg, borderRadius: BorderRadius.circular(5)),
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
                        SizedBox(height: 2),
                        Text(customer['address'] ?? customer['phone'] ?? '—',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  // Status dropdown trigger
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
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
                                  Text(_capitalize(o['status'] ?? ''), style: TextStyle(
                                    color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                                  SizedBox(width: 3),
                                  Icon(Icons.expand_more_rounded, size: 12,
                                    color: statusColor.withOpacity(0.7)),
                                ]),
                        ),
                      ),
                      SizedBox(height: 8),
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
                // Animated checkbox
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
                Text("Rp ${_formatPrice(qty * price)}", style: TextStyle(
                  color: isPrepared ? Color(0xFF4A5568) : Color(0xFF10B981),
                  fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          );
        }),
      ],

      // Totals block
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
        Text("Rp ${_formatPrice(amount)}", style: TextStyle(
          color: valueColor, fontSize: large ? 15 : 12, fontWeight: FontWeight.w800)),
      ],
    );
  }
}