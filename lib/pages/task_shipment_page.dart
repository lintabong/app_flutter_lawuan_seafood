
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../helpers/cached_tile_provider.dart';

/// DRIVER point-of-view.
/// Shows this driver's own live position + the orders assigned to them today.
/// A Start/Stop control shares location every 15s (foreground only) and flips
/// all still-assigned orders to `en_route`. Per-order buttons advance the
/// shipment status and capture optional text proof. None of this touches
/// `orders.status` — the admin verifies and marks orders delivered separately.
class TaskShipmentPage extends StatefulWidget {
  @override
  State<TaskShipmentPage> createState() => _TaskShipmentPageState();
}

class _TaskShipmentPageState extends State<TaskShipmentPage> {
  final String? driverId = SupabaseService.currentUserId;

  List shipments = [];
  bool loading = true;
  DateTime selectedDate = DateTime.now();

  LatLng? _myLatLng;
  bool _isSending = false;
  bool _centeredOnce = false;
  Timer? _locTimer;

  final Set<int> _updating = {};
  int? selectedIndex;

  final MapController _mapController = MapController();

  static const LatLng _depot  = LatLng(-7.586647230136144, 110.94508655273896);
  static const Color  _cyan   = Color(0xFF06B6D4);
  static const Color  _green  = Color(0xFF10B981);
  static const Color  _amber  = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _locTimer?.cancel();
    // Leaving the page counts as going offline for the monitor.
    if (_isSending && driverId != null) {
      SupabaseService.stopDriverLocation(driverId!);
    }
    super.dispose();
  }

  Future _load() async {
    if (driverId == null) {
      setState(() => loading = false);
      return;
    }
    setState(() { loading = true; selectedIndex = null; });
    final data = await SupabaseService.getMyShipments(
      driverId: driverId!, date: selectedDate);
    if (!mounted) return;
    setState(() { shipments = data; loading = false; });
    final first = _firstOrderLatLng();
    if (first != null && !_centeredOnce) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _mapController.move(first, 13);
      });
    }
  }

  LatLng? _firstOrderLatLng() {
    for (final s in shipments) {
      final c   = s['orders']?['customers'];
      final lat = double.tryParse(c?['latitude']?.toString()  ?? '');
      final lng = double.tryParse(c?['longitude']?.toString() ?? '');
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  // ── Live location ──────────────────────────────────────────────────────────

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _snack('Turn on device location, then try again.');
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      _snack('Location permission is required to share your position.');
      return false;
    }
    return true;
  }

  Future<void> _sendOnce() async {
    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      );
      final pos = await Geolocator.getCurrentPosition(locationSettings: settings);
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _myLatLng = here);
      if (!_centeredOnce) {
        _centeredOnce = true;
        _mapController.move(here, 15);
      }
      await SupabaseService.updateDriverLocation(
        driverId: driverId!,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        heading: pos.heading,
        speed: pos.speed,
      );
    } catch (_) {
      // A single failed fix (timeout / weak signal) is fine; next tick retries.
    }
  }

  Future<void> _startLive() async {
    if (driverId == null) return;
    if (!await _ensurePermission()) return;
    setState(() => _isSending = true);
    await SupabaseService.startEnRouteForDriver(driverId!); // all assigned -> en_route
    await _sendOnce();
    await _load(); // reflect the en_route flip
    _locTimer?.cancel();
    _locTimer = Timer.periodic(const Duration(seconds: 15), (_) => _sendOnce());
  }

  Future<void> _stopLive() async {
    _locTimer?.cancel();
    _locTimer = null;
    setState(() => _isSending = false);
    if (driverId != null) await SupabaseService.stopDriverLocation(driverId!);
  }

  // ── Status transitions ─────────────────────────────────────────────────────

  Future<void> _setStatus(int shipmentId, String status,
      {String? recipient, String? note, String? failure}) async {
    if (_updating.contains(shipmentId)) return;
    setState(() => _updating.add(shipmentId));
    try {
      await SupabaseService.updateShipmentStatus(
        shipmentId: shipmentId,
        newStatus: status,
        recipientName: recipient,
        note: note,
        failureReason: failure,
      );
      await _load();
    } catch (e) {
      _snack('Failed to update: $e');
    } finally {
      if (mounted) setState(() => _updating.remove(shipmentId));
    }
  }

  void _openCompleteSheet(int shipmentId, Map ship) {
    final recipientCtrl = TextEditingController(text: ship['recipient_name']?.toString() ?? '');
    final noteCtrl      = TextEditingController(text: ship['note']?.toString() ?? '');
    _openProofSheet(
      title: 'Mark delivered',
      accent: _green,
      confirmLabel: 'Confirm delivered',
      fields: [
        _SheetField(controller: recipientCtrl, label: 'Received by (optional)', hint: 'e.g. Bu Sri'),
        _SheetField(controller: noteCtrl, label: 'Note (optional)', hint: 'Left at front door…', lines: 3),
      ],
      onConfirm: () => _setStatus(shipmentId, 'completed',
        recipient: recipientCtrl.text.trim().isEmpty ? null : recipientCtrl.text.trim(),
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim()),
    );
  }

  void _openFailSheet(int shipmentId, Map ship) {
    final reasonCtrl = TextEditingController(text: ship['failure_reason']?.toString() ?? '');
    _openProofSheet(
      title: 'Mark failed',
      accent: const Color(0xFFEF4444),
      confirmLabel: 'Confirm failed',
      fields: [
        _SheetField(controller: reasonCtrl, label: 'Reason (optional)', hint: 'Customer not home…', lines: 3),
      ],
      onConfirm: () => _setStatus(shipmentId, 'failed',
        failure: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim()),
    );
  }

  void _openProofSheet({
    required String title,
    required Color accent,
    required String confirmLabel,
    required List<_SheetField> fields,
    required VoidCallback onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161B27),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.fromBorderSide(BorderSide(color: Color(0xFF222840), width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: const Color(0xFF2A3040), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Text(title, style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              ...fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.label, style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: f.controller,
                      maxLines: f.lines,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: f.hint,
                        hintStyle: const TextStyle(color: Color(0xFF4A5568), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF0F1117),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: const BorderSide(color: Color(0xFF222840))),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: BorderSide(color: accent.withOpacity(0.6))),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); onConfirm(); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(confirmLabel, style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Date + misc ─────────────────────────────────────────────────────────────

  Future _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2200),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _cyan, surface: Color(0xFF161B27), onSurface: Colors.white),
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1E2333)));
  }

  void _flyTo(Map ship) {
    final c   = ship['orders']?['customers'];
    final lat = double.tryParse(c?['latitude']?.toString()  ?? '');
    final lng = double.tryParse(c?['longitude']?.toString() ?? '');
    if (lat != null && lng != null) _mapController.move(LatLng(lat, lng), 15);
  }

  String _formatPrice(dynamic p) {
    if (p == null) return '0';
    final n = double.tryParse(p.toString()) ?? 0;
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

  Map<String, dynamic> _shipStyle(String? s) {
    switch (s) {
      case 'assigned':  return {'color': const Color(0xFF94A3B8), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.assignment_ind_rounded, 'label': 'Assigned'};
      case 'en_route':  return {'color': const Color(0xFF3B82F6), 'bg': const Color(0xFF0B1D3A), 'icon': Icons.local_shipping_rounded, 'label': 'En route'};
      case 'arrived':   return {'color': const Color(0xFF8B5CF6), 'bg': const Color(0xFF1C1030), 'icon': Icons.pin_drop_rounded,       'label': 'Arrived'};
      case 'completed': return {'color': const Color(0xFF10B981), 'bg': const Color(0xFF062318), 'icon': Icons.check_circle_rounded,   'label': 'Delivered'};
      case 'failed':    return {'color': const Color(0xFFEF4444), 'bg': const Color(0xFF2D0A0A), 'icon': Icons.error_outline_rounded,  'label': 'Failed'};
      case 'cancelled': return {'color': const Color(0xFF64748B), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.block_rounded,          'label': 'Cancelled'};
      default:          return {'color': const Color(0xFF4A5568), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.help_outline_rounded,   'label': '—'};
    }
  }

  // ── Markers ────────────────────────────────────────────────────────────────

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Depot
    markers.add(Marker(
      point: _depot, width: 44, height: 54,
      child: Column(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2D1200), shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF97316), width: 2)),
          child: const Icon(Icons.store_rounded, color: Color(0xFFF97316), size: 16)),
        Container(width: 2, height: 10, color: const Color(0xFFF97316)),
        Container(width: 6, height: 6,
          decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle)),
      ]),
    ));

    // Orders assigned to me
    for (int i = 0; i < shipments.length; i++) {
      final s   = shipments[i];
      final c   = s['orders']?['customers'];
      final lat = double.tryParse(c?['latitude']?.toString()  ?? '');
      final lng = double.tryParse(c?['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;
      final isSel = selectedIndex == i;
      final col   = _shipStyle(s['status'])['color'] as Color;

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: isSel ? 52 : 38, height: isSel ? 62 : 48,
        child: GestureDetector(
          onTap: () {
            setState(() => selectedIndex = isSel ? null : i);
            if (!isSel) _flyTo(s);
          },
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSel ? 40 : 30, height: isSel ? 40 : 30,
              decoration: BoxDecoration(
                color: const Color(0xFF161B27), shape: BoxShape.circle,
                border: Border.all(color: col, width: isSel ? 2.5 : 1.5),
                boxShadow: [BoxShadow(color: col.withOpacity(isSel ? 0.5 : 0.2), blurRadius: isSel ? 14 : 6)]),
              child: Icon(Icons.delivery_dining_rounded, color: col, size: isSel ? 20 : 15)),
            Container(width: 2, height: isSel ? 12 : 9, color: col),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          ]),
        ),
      ));
    }

    // My own position
    if (_myLatLng != null) {
      markers.add(Marker(
        point: _myLatLng!, width: 54, height: 54,
        child: Container(
          decoration: BoxDecoration(
            color: _green.withOpacity(0.15), shape: BoxShape.circle),
          child: Center(
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF062318), shape: BoxShape.circle,
                border: Border.all(color: _green, width: 3),
                boxShadow: [BoxShadow(color: _green.withOpacity(0.6), blurRadius: 16)]),
              child: const Icon(Icons.navigation_rounded, color: _green, size: 16)),
          ),
        ),
      ));
    }

    return markers;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (driverId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F1117),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.badge_outlined, color: Color(0xFF2A3040), size: 52),
            SizedBox(height: 14),
            Text("No driver identity",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text("Set kFallbackUserId (or sign in) before using this page.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ]),
        )),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: SafeArea(
        child: Column(children: [
          // MAP
          Expanded(
            flex: 4,
            child: Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: _depot,
                    initialZoom: 12,
                    interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'app_flutter_lawuan_seafood',
                      maxZoom: 19,
                      tileProvider: CachedTileProvider(),
                      tileBuilder: (ctx, tile, _) => ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
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

              Positioned(top: 16, left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xE6161B27), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A3040), width: 1)),
                    child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF94A3B8), size: 20)),
                ),
              ),

              Positioned(top: 16, left: 68, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xE6161B27), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A3040), width: 1)),
                  child: Row(children: [
                    const Icon(Icons.route_rounded, color: _cyan, size: 16),
                    const SizedBox(width: 8),
                    const Text("My Deliveries", style: TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(width: 8, height: 8, decoration: BoxDecoration(
                      color: _isSending ? _green : const Color(0xFF64748B), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(_isSending ? "Live" : "Off",
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ]),
                ),
              ),

              // Recenter on me
              if (_myLatLng != null)
                Positioned(bottom: 40, right: 14,
                  child: GestureDetector(
                    onTap: () => _mapController.move(_myLatLng!, 16),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xE6161B27), borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _green.withOpacity(0.5), width: 1)),
                      child: const Icon(Icons.my_location_rounded, color: _green, size: 20)),
                  ),
                ),

              Positioned(bottom: 8, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(4)),
                  child: const Text("© OpenStreetMap contributors",
                    style: TextStyle(color: Colors.white70, fontSize: 9))),
              ),
            ]),
          ),

          // Live loc control bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _buildLiveBar(),
          ),

          // Date bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B27), borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFF222840), width: 1)),
                child: Row(children: [
                  Container(width: 30, height: 30,
                    decoration: BoxDecoration(color: const Color(0xFF0C2A3A), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.calendar_today_rounded, size: 14, color: _cyan)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _isToday(selectedDate) ? "Today — ${_formatFullDate(selectedDate)}" : _formatFullDate(selectedDate),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                  const Icon(Icons.expand_more_rounded, color: Color(0xFF4A5568), size: 18),
                ]),
              ),
            ),
          ),

          // List
          Expanded(
            child: loading
                ? const Center(child: SizedBox(width: 32, height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: _cyan)))
                : shipments.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.inbox_rounded, color: Color(0xFF2A3040), size: 52),
                          SizedBox(height: 12),
                          Text("Nothing assigned to you today",
                            style: TextStyle(color: Color(0xFF4A5568), fontSize: 14)),
                        ]))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: shipments.length,
                        itemBuilder: (ctx, i) => _buildCard(ctx, i),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _buildLiveBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isSending ? _green.withOpacity(0.4) : const Color(0xFF222840), width: 1),
      ),
      child: Row(children: [
        const SizedBox(width: 8),
        Container(width: 9, height: 9, decoration: BoxDecoration(
          color: _isSending ? _green : const Color(0xFF4A5568), shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isSending ? "Sharing location" : "Location off",
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(_isSending ? "Sending every 15s · starts all orders" : "Start to go en route",
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
          ],
        )),
        GestureDetector(
          onTap: _isSending ? _stopLive : _startLive,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: _isSending ? const Color(0xFF2D0A0A) : _green,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isSending ? const Color(0xFFEF4444).withOpacity(0.5) : Colors.transparent, width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isSending ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: _isSending ? const Color(0xFFEF4444) : Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(_isSending ? "Stop" : "Start",
                style: TextStyle(
                  color: _isSending ? const Color(0xFFEF4444) : Colors.white,
                  fontSize: 13, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildCard(BuildContext context, int i) {
    final s        = shipments[i];
    final shipId   = s['id'] as int;
    final order    = s['orders'] as Map? ?? {};
    final customer = order['customers'] as Map? ?? {};
    final items    = (order['order_items'] as List?) ?? [];
    final status   = s['status']?.toString() ?? 'assigned';
    final sst      = _shipStyle(status);
    final isSel    = selectedIndex == i;
    final busy     = _updating.contains(shipId);
    final hasCoords = double.tryParse(customer['latitude']?.toString() ?? '') != null;
    final total    = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: () {
        final was = selectedIndex == i;
        setState(() => selectedIndex = was ? null : i);
        if (!was) _flyTo(s);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B27),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSel ? _cyan.withOpacity(0.5) : const Color(0xFF222840),
            width: isSel ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (sst['bg'] as Color), borderRadius: BorderRadius.circular(12)),
                  child: Icon(sst['icon'], color: sst['color'], size: 19)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text("#${order['id']}", style: const TextStyle(
                        color: _amber, fontSize: 12, fontWeight: FontWeight.w700)),
                      if (hasCoords) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.location_on_rounded, size: 11, color: _cyan),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(customer['name'] ?? 'Unknown', style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(customer['address'] ?? customer['phone'] ?? '—',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: sst['bg'], borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: (sst['color'] as Color).withOpacity(0.35), width: 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(sst['icon'], size: 11, color: sst['color']),
                    const SizedBox(width: 4),
                    Text(sst['label'], style: TextStyle(
                      color: sst['color'], fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ),

            // Item summary + total
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                items.map((it) {
                  final q = double.tryParse(it['quantity'].toString()) ?? 0;
                  final unit = it['products']?['unit'] ?? '';
                  final name = it['products']?['name'] ?? '—';
                  final qs = q % 1 == 0 ? q.toInt().toString() : q.toString();
                  return "$qs$unit $name";
                }).join(' · '),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.3)),
            ],

            if (s['recipient_name'] != null || s['failure_reason'] != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(status == 'failed' ? Icons.info_outline_rounded : Icons.how_to_reg_rounded,
                  size: 13, color: status == 'failed' ? const Color(0xFFEF4444) : _green),
                const SizedBox(width: 5),
                Expanded(child: Text(
                  s['failure_reason']?.toString() ?? "Received by ${s['recipient_name']}",
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11))),
              ]),
            ],

            const SizedBox(height: 12),
            const Divider(color: Color(0xFF222840), height: 1),
            const SizedBox(height: 12),

            Row(children: [
              Text("Rp ${_formatPrice(total)}", style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (busy)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _cyan))
              else
                ..._actions(shipId, status, s),
            ]),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(int shipId, String status, Map ship) {
    Widget btn(String label, IconData icon, Color color, VoidCallback onTap, {bool filled = false}) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: filled ? color : color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: filled ? Colors.transparent : color.withOpacity(0.4), width: 1)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: filled ? Colors.white : color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(
                color: filled ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
    }

    switch (status) {
      case 'assigned':
        return [btn('Depart', Icons.play_arrow_rounded, const Color(0xFF3B82F6),
          () => _setStatus(shipId, 'en_route'), filled: true)];
      case 'en_route':
        return [
          btn('Failed', Icons.close_rounded, const Color(0xFFEF4444), () => _openFailSheet(shipId, ship)),
          btn('Arrived', Icons.pin_drop_rounded, const Color(0xFF8B5CF6), () => _setStatus(shipId, 'arrived'), filled: true),
        ];
      case 'arrived':
        return [
          btn('Failed', Icons.close_rounded, const Color(0xFFEF4444), () => _openFailSheet(shipId, ship)),
          btn('Delivered', Icons.check_rounded, _green, () => _openCompleteSheet(shipId, ship), filled: true),
        ];
      default: // completed / failed / cancelled
        return [btn('Reopen', Icons.refresh_rounded, const Color(0xFF64748B),
          () => _setStatus(shipId, 'en_route'))];
    }
  }
}

class _SheetField {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int lines;
  _SheetField({required this.controller, required this.label, this.hint = '', this.lines = 1});
}