
// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import '../services/supabase_service.dart';
// import '../helpers/cached_tile_provider.dart';

// /// ADMIN point-of-view.
// /// See the day's delivery orders on a map, assign each to a driver (including
// /// yourself), and watch live driver positions. Fully isolated from order status
// /// — assigning/tracking never changes `orders.status`.
// class DriverShipmentPage extends StatefulWidget {
//   @override
//   State<DriverShipmentPage> createState() => _DriverShipmentPageState();
// }

// class _DriverShipmentPageState extends State<DriverShipmentPage> {
//   List orders = [];
//   Map<int, Map<String, dynamic>> shipments = {}; // order_id -> shipment
//   List users = [];
//   List driverLocs = [];
//   bool loading = true;

//   DateTime selectedDate = DateTime.now();
//   int? selectedOrderIndex;

//   final Set<int> _assigning = {};

//   final MapController _mapController = MapController();
//   Timer? _liveTimer;

//   static const LatLng _depot  = LatLng(-7.586647230136144, 110.94508655273896);
//   static const Color  _cyan   = Color(0xFF06B6D4);
//   static const Color  _cyanBg = Color(0xFF0C2A3A);
//   static const Color  _amber  = Color(0xFFF59E0B);

//   @override
//   void initState() {
//     super.initState();
//     _load();
//     _liveTimer = Timer.periodic(
//       const Duration(seconds: 10),
//       (_) => _refreshLive(),
//     );
//   }

//   @override
//   void dispose() {
//     _liveTimer?.cancel();
//     super.dispose();
//   }

//   Future _load() async {
//     setState(() { loading = true; selectedOrderIndex = null; });
//     final data = await SupabaseService.getOrders(
//       date: selectedDate,
//       deliveryType: 'delivery',
//       withItems: false,
//       pageSize: 100,
//     );
//     final ids = <int>[for (final o in data) o['id'] as int];
//     final results = await Future.wait([
//       SupabaseService.getShipmentsByOrderIds(ids),
//       SupabaseService.getActiveUsers(),
//       SupabaseService.getDriverLocations(),
//     ]);
//     if (!mounted) return;
//     setState(() {
//       orders     = data;
//       shipments  = results[0] as Map<int, Map<String, dynamic>>;
//       users      = results[1] as List;
//       driverLocs = results[2] as List;
//       loading    = false;
//     });
//     final first = _firstWithCoords();
//     if (first != null) {
//       Future.delayed(const Duration(milliseconds: 400), () {
//         if (mounted) _mapController.move(first, 13);
//       });
//     }
//   }

//   // Lightweight poll: shipment statuses + driver positions only.
//   Future _refreshLive() async {
//     if (orders.isEmpty) {
//       final locs = await SupabaseService.getDriverLocations();
//       if (mounted) setState(() => driverLocs = locs);
//       return;
//     }
//     final ids = <int>[for (final o in orders) o['id'] as int];
//     final results = await Future.wait([
//       SupabaseService.getShipmentsByOrderIds(ids),
//       SupabaseService.getDriverLocations(),
//     ]);
//     if (!mounted) return;
//     setState(() {
//       shipments  = results[0] as Map<int, Map<String, dynamic>>;
//       driverLocs = results[1] as List;
//     });
//   }

//   LatLng? _firstWithCoords() {
//     for (final o in orders) {
//       final c   = o['customers'];
//       final lat = double.tryParse(c?['latitude']?.toString()  ?? '');
//       final lng = double.tryParse(c?['longitude']?.toString() ?? '');
//       if (lat != null && lng != null) return LatLng(lat, lng);
//     }
//     return null;
//   }

//   void _flyTo(Map order) {
//     final c   = order['customers'];
//     final lat = double.tryParse(c?['latitude']?.toString()  ?? '');
//     final lng = double.tryParse(c?['longitude']?.toString() ?? '');
//     if (lat != null && lng != null) _mapController.move(LatLng(lat, lng), 15);
//   }

//   // ── Assign ───────────────────────────────────────────────────────────────

//   void _showAssignSheet(BuildContext context, int oi) {
//     final order   = orders[oi];
//     final orderId = order['id'] as int;
//     final current = shipments[orderId];
//     final currentDriverId = current?['driver_id']?.toString();

//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       builder: (_) => Container(
//         decoration: const BoxDecoration(
//           color: Color(0xFF161B27),
//           borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//           border: Border.fromBorderSide(BorderSide(color: Color(0xFF222840), width: 1)),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const SizedBox(height: 12),
//             Container(width: 36, height: 4,
//               decoration: BoxDecoration(color: const Color(0xFF2A3040), borderRadius: BorderRadius.circular(2))),
//             const SizedBox(height: 18),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 24),
//               child: Row(children: [
//                 const Text("Assign driver", style: TextStyle(
//                   color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
//                 const Spacer(),
//                 Text("#$orderId", style: const TextStyle(
//                   color: _amber, fontSize: 13, fontWeight: FontWeight.w700)),
//               ]),
//             ),
//             const SizedBox(height: 12),
//             if (users.isEmpty)
//               const Padding(
//                 padding: EdgeInsets.all(24),
//                 child: Text("No active users found",
//                   style: TextStyle(color: Color(0xFF4A5568), fontSize: 13)),
//               ),
//             ...users.map((u) {
//               final uid       = u['id'].toString();
//               final isCurrent = uid == currentDriverId;
//               final initials  = _initials(u['name']?.toString() ?? '?');
//               return ListTile(
//                 contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
//                 leading: Container(
//                   width: 40, height: 40,
//                   decoration: BoxDecoration(
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)],
//                       begin: Alignment.topLeft, end: Alignment.bottomRight),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Center(child: Text(initials, style: const TextStyle(
//                     color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
//                 ),
//                 title: Text(u['name']?.toString() ?? '—', style: TextStyle(
//                   color: isCurrent ? _cyan : Colors.white,
//                   fontSize: 14, fontWeight: FontWeight.w600)),
//                 subtitle: Text((u['role']?.toString() ?? '').toUpperCase(),
//                   style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5,
//                     fontWeight: FontWeight.w600, letterSpacing: 0.4)),
//                 trailing: isCurrent
//                     ? const Icon(Icons.check_circle_rounded, color: _cyan, size: 20)
//                     : const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF4A5568), size: 13),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _assign(oi, uid);
//                 },
//               );
//             }),
//             const SizedBox(height: 24),
//           ],
//         ),
//       ),
//     );
//   }

//   Future _confirmCancel(BuildContext context, int oi) async {
//   final orderId = orders[oi]['id'] as int;
//   final ok = await showDialog<bool>(
//     context: context,
//     builder: (ctx) => AlertDialog(
//       backgroundColor: const Color(0xFF161B27),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
//       title: const Text('Cancel assignment',
//         style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
//       content: Text('Remove the shipment for order #$orderId? This deletes it from the database.',
//         style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
//       actions: [
//         TextButton(onPressed: () => Navigator.pop(ctx, false),
//           child: const Text('Keep', style: TextStyle(color: Color(0xFF94A3B8)))),
//         TextButton(onPressed: () => Navigator.pop(ctx, true),
//           child: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700))),
//       ],
//     ),
//   );
//   if (ok == true) _cancelAssign(oi);
// }

// Future _cancelAssign(int oi) async {
//   final orderId = orders[oi]['id'] as int;
//   if (_assigning.contains(orderId)) return;
//   setState(() => _assigning.add(orderId));
//   try {
//     await SupabaseService.deleteShipment(orderId);
//     setState(() => shipments.remove(orderId));
//   } catch (e) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text('Failed to cancel: $e'),
//         backgroundColor: const Color(0xFF2D0A0A)));
//     }
//   } finally {
//     if (mounted) setState(() => _assigning.remove(orderId));
//   }
// }

//   Future _assign(int oi, String driverId) async {
//     final orderId = orders[oi]['id'] as int;
//     if (_assigning.contains(orderId)) return;
//     setState(() => _assigning.add(orderId));
//     try {
//       // final ship = await SupabaseService.assignShipment(
//       //   orderId: orderId, driverId: driverId);
//       // // fetch driver name for immediate display
//       // final u = users.firstWhere(
//       //   (x) => x['id'].toString() == driverId, orElse: () => null);
//       // if (u != null) ship['driver'] = {'id': u['id'], 'name': u['name']};
//       // setState(() => shipments[orderId] = Map<String, dynamic>.from(ship));
//       final ship = await SupabaseService.assignShipment(
//         orderId: orderId, driverId: driverId);
//       // fetch driver name for immediate display
//       Map<String, dynamic>? u;
//       for (final x in users) {
//         if (x['id'].toString() == driverId) {
//           u = Map<String, dynamic>.from(x);
//           break;
//         }
//       }
//       if (u != null) ship['driver'] = {'id': u['id'], 'name': u['name']};
//       setState(() => shipments[orderId] = Map<String, dynamic>.from(ship));
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Failed to assign: $e'),
//           backgroundColor: const Color(0xFF2D0A0A)));
//       }
//     } finally {
//       if (mounted) setState(() => _assigning.remove(orderId));
//     }
//   }

//   // ── Date picker ────────────────────────────────────────────────────────────

//   Future _pickDate(BuildContext context) async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: selectedDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime(2200),
//       builder: (ctx, child) => Theme(
//         data: Theme.of(ctx).copyWith(
//           colorScheme: const ColorScheme.dark(
//             primary: _cyan, surface: Color(0xFF161B27), onSurface: Colors.white),
//           dialogBackgroundColor: const Color(0xFF161B27),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null) {
//       setState(() => selectedDate = picked);
//       _load();
//     }
//   }

//   // ── Helpers ────────────────────────────────────────────────────────────────

//   String _initials(String name) => name
//       .trim().split(RegExp(r'\s+')).take(2)
//       .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

//   String _formatFullDate(DateTime d) {
//     const m = ['January','February','March','April','May','June',
//         'July','August','September','October','November','December'];
//     return "${d.day} ${m[d.month - 1]} ${d.year}";
//   }

//   bool _isToday(DateTime d) {
//     final n = DateTime.now();
//     return d.year == n.year && d.month == n.month && d.day == n.day;
//   }

//   String _capitalize(String s) =>
//       s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

//   Map<String, dynamic> _orderStyle(String? s) {
//     switch (s) {
//       case 'pending':   return {'color': const Color(0xFFF59E0B), 'bg': const Color(0xFF2D1F0A), 'icon': Icons.hourglass_empty_rounded};
//       case 'prepared':  return {'color': const Color(0xFF06B6D4), 'bg': const Color(0xFF0C2A3A), 'icon': Icons.kitchen_rounded};
//       case 'paid':      return {'color': const Color(0xFF6C63FF), 'bg': const Color(0xFF1E1B4B), 'icon': Icons.payments_rounded};
//       case 'delivered': return {'color': const Color(0xFF10B981), 'bg': const Color(0xFF062318), 'icon': Icons.task_alt_rounded};
//       case 'cancelled': return {'color': const Color(0xFFEF4444), 'bg': const Color(0xFF2D0A0A), 'icon': Icons.cancel_outlined};
//       default:          return {'color': const Color(0xFF94A3B8), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.circle_outlined};
//     }
//   }

//   Map<String, dynamic> _shipStyle(String? s) {
//     switch (s) {
//       case 'assigned':  return {'color': const Color(0xFF94A3B8), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.assignment_ind_rounded,  'label': 'Assigned'};
//       case 'en_route':  return {'color': const Color(0xFF3B82F6), 'bg': const Color(0xFF0B1D3A), 'icon': Icons.local_shipping_rounded,  'label': 'En route'};
//       case 'arrived':   return {'color': const Color(0xFF8B5CF6), 'bg': const Color(0xFF1C1030), 'icon': Icons.pin_drop_rounded,        'label': 'Arrived'};
//       case 'completed': return {'color': const Color(0xFF10B981), 'bg': const Color(0xFF062318), 'icon': Icons.check_circle_rounded,    'label': 'Completed'};
//       case 'failed':    return {'color': const Color(0xFFEF4444), 'bg': const Color(0xFF2D0A0A), 'icon': Icons.error_outline_rounded,   'label': 'Failed'};
//       case 'cancelled': return {'color': const Color(0xFF64748B), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.block_rounded,           'label': 'Cancelled'};
//       default:          return {'color': const Color(0xFF4A5568), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.help_outline_rounded,    'label': 'Unassigned'};
//     }
//   }

//   bool _isStale(dynamic updatedAt) {
//     final t = DateTime.tryParse(updatedAt?.toString() ?? '');
//     if (t == null) return true;
//     return DateTime.now().toUtc().difference(t.toUtc()).inSeconds > 30;
//   }

//   // ── Markers ────────────────────────────────────────────────────────────────

//   List<Marker> _buildMarkers() {
//     final markers = <Marker>[];

//     // Depot
//     markers.add(Marker(
//       point: _depot, width: 48, height: 58,
//       child: Column(children: [
//         Container(
//           width: 36, height: 36,
//           decoration: BoxDecoration(
//             color: const Color(0xFF2D1200), shape: BoxShape.circle,
//             border: Border.all(color: const Color(0xFFF97316), width: 2),
//             boxShadow: [BoxShadow(color: const Color(0xFFF97316).withOpacity(0.4), blurRadius: 12)],
//           ),
//           child: const Icon(Icons.store_rounded, color: Color(0xFFF97316), size: 18),
//         ),
//         Container(width: 2, height: 12, color: const Color(0xFFF97316)),
//         Container(width: 6, height: 6,
//           decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle)),
//       ]),
//     ));

//     // Orders
//     for (int i = 0; i < orders.length; i++) {
//       final o   = orders[i];
//       final c   = o['customers'];
//       final lat = double.tryParse(c?['latitude']?.toString()  ?? '');
//       final lng = double.tryParse(c?['longitude']?.toString() ?? '');
//       if (lat == null || lng == null) continue;

//       final orderId    = o['id'] as int;
//       final ship       = shipments[orderId];
//       final isSelected = selectedOrderIndex == i;
//       final baseColor  = ship != null
//           ? _shipStyle(ship['status'])['color'] as Color
//           : _orderStyle(o['status'])['color'] as Color;
//       final dotColor   = isSelected ? _cyan : baseColor;

//       markers.add(Marker(
//         point: LatLng(lat, lng),
//         width: isSelected ? 56 : 40,
//         height: isSelected ? 66 : 50,
//         child: GestureDetector(
//           onTap: () {
//             setState(() => selectedOrderIndex = selectedOrderIndex == i ? null : i);
//             if (selectedOrderIndex == i) _flyTo(o);
//           },
//           child: Column(children: [
//             AnimatedContainer(
//               duration: const Duration(milliseconds: 200),
//               width: isSelected ? 44 : 32, height: isSelected ? 44 : 32,
//               decoration: BoxDecoration(
//                 color: isSelected ? _cyanBg : const Color(0xFF161B27),
//                 shape: BoxShape.circle,
//                 border: Border.all(color: dotColor, width: isSelected ? 2.5 : 1.5),
//                 boxShadow: [BoxShadow(color: dotColor.withOpacity(isSelected ? 0.5 : 0.2),
//                   blurRadius: isSelected ? 16 : 6)],
//               ),
//               child: Icon(Icons.delivery_dining_rounded, color: dotColor, size: isSelected ? 22 : 16),
//             ),
//             Container(width: isSelected ? 3 : 2, height: isSelected ? 14 : 10, color: dotColor),
//             Container(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6,
//               decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
//           ]),
//         ),
//       ));
//     }

//     // Drivers
//     for (final d in driverLocs) {
//       final lat = double.tryParse(d['latitude']?.toString()  ?? '');
//       final lng = double.tryParse(d['longitude']?.toString() ?? '');
//       if (lat == null || lng == null) continue;
//       final stale = _isStale(d['updated_at']);
//       final name  = (d['users']?['name']?.toString() ?? 'Driver');
//       final col   = stale ? const Color(0xFF64748B) : const Color(0xFF10B981);

//       markers.add(Marker(
//         point: LatLng(lat, lng), width: 90, height: 62,
//         child: Column(children: [
//           Container(
//             width: 38, height: 38,
//             decoration: BoxDecoration(
//               color: const Color(0xFF062318), shape: BoxShape.circle,
//               border: Border.all(color: col, width: 2.5),
//               boxShadow: [BoxShadow(color: col.withOpacity(stale ? 0.2 : 0.55), blurRadius: stale ? 6 : 16)],
//             ),
//             child: Icon(Icons.navigation_rounded, color: col, size: 18),
//           ),
//           const SizedBox(height: 3),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//             decoration: BoxDecoration(
//               color: const Color(0xE6161B27), borderRadius: BorderRadius.circular(6),
//               border: Border.all(color: col.withOpacity(0.5), width: 1),
//             ),
//             child: Text(stale ? '$name · idle' : name,
//               maxLines: 1, overflow: TextOverflow.ellipsis,
//               style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.w700)),
//           ),
//         ]),
//       ));
//     }

//     return markers;
//   }

//   // ── Build ──────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final online = driverLocs.where((d) => !_isStale(d['updated_at'])).length;
//     return Scaffold(
//       backgroundColor: const Color(0xFF0F1117),
//       body: SafeArea(
//         child: Column(children: [
//           // MAP
//           Expanded(
//             flex: 5,
//             child: Stack(children: [
//               ClipRRect(
//                 borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
//                 child: FlutterMap(
//                   mapController: _mapController,
//                   options: MapOptions(
//                     initialCenter: _depot,
//                     initialZoom: 12,
//                     interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
//                   ),
//                   children: [
//                     TileLayer(
//                       urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                       userAgentPackageName: 'app_flutter_lawuan_seafood',
//                       maxZoom: 19,
//                       tileProvider: CachedTileProvider(),
//                       tileBuilder: (ctx, tile, _) => ColorFiltered(
//                         colorFilter: const ColorFilter.matrix([
//                           0.30, 0.0, 0.0, 0, 20,
//                           0.00, 0.3, 0.0, 0, 20,
//                           0.00, 0.0, 0.4, 0, 30,
//                           0.00, 0.0, 0.0, 1,  0,
//                         ]),
//                         child: tile,
//                       ),
//                     ),
//                     MarkerLayer(markers: _buildMarkers()),
//                   ],
//                 ),
//               ),

//               // Back button
//               Positioned(top: 16, left: 16,
//                 child: GestureDetector(
//                   onTap: () => Navigator.pop(context),
//                   child: Container(
//                     width: 40, height: 40,
//                     decoration: BoxDecoration(
//                       color: const Color(0xE6161B27), borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: const Color(0xFF2A3040), width: 1)),
//                     child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF94A3B8), size: 20),
//                   ),
//                 ),
//               ),

//               // Title overlay
//               Positioned(top: 16, left: 68, right: 16,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//                   decoration: BoxDecoration(
//                     color: const Color(0xE6161B27), borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: const Color(0xFF2A3040), width: 1)),
//                   child: Row(children: [
//                     const Icon(Icons.local_shipping_rounded, color: _cyan, size: 16),
//                     const SizedBox(width: 8),
//                     const Text("Driver Shipments", style: TextStyle(
//                       color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
//                     const Spacer(),
//                     Container(
//                       width: 8, height: 8,
//                       decoration: BoxDecoration(
//                         color: online > 0 ? const Color(0xFF10B981) : const Color(0xFF64748B),
//                         shape: BoxShape.circle)),
//                     const SizedBox(width: 5),
//                     Text("$online live", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
//                   ]),
//                 ),
//               ),

//               Positioned(bottom: 28, right: 10,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
//                   decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(4)),
//                   child: const Text("© OpenStreetMap contributors",
//                     style: TextStyle(color: Colors.white70, fontSize: 9)),
//                 ),
//               ),
//             ]),
//           ),

//           // LIST
//           Expanded(
//             flex: 6,
//             child: Column(children: [
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
//                 child: GestureDetector(
//                   onTap: () => _pickDate(context),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF161B27), borderRadius: BorderRadius.circular(13),
//                       border: Border.all(color: const Color(0xFF222840), width: 1)),
//                     child: Row(children: [
//                       Container(
//                         width: 30, height: 30,
//                         decoration: BoxDecoration(color: _cyanBg, borderRadius: BorderRadius.circular(8)),
//                         child: const Icon(Icons.calendar_today_rounded, size: 14, color: _cyan)),
//                       const SizedBox(width: 10),
//                       Expanded(child: Text(
//                         _isToday(selectedDate)
//                             ? "Today — ${_formatFullDate(selectedDate)}"
//                             : _formatFullDate(selectedDate),
//                         style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
//                       const Icon(Icons.expand_more_rounded, color: Color(0xFF4A5568), size: 18),
//                     ]),
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: loading
//                     ? const Center(child: SizedBox(width: 32, height: 32,
//                         child: CircularProgressIndicator(strokeWidth: 2.5, color: _cyan)))
//                     : orders.isEmpty
//                         ? Center(child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: const [
//                               Icon(Icons.local_shipping_outlined, color: Color(0xFF2A3040), size: 52),
//                               SizedBox(height: 12),
//                               Text("No deliveries on this date",
//                                 style: TextStyle(color: Color(0xFF4A5568), fontSize: 14)),
//                             ]))
//                         : ListView.builder(
//                             padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
//                             itemCount: orders.length,
//                             itemBuilder: (ctx, i) => _buildCard(ctx, i),
//                           ),
//               ),
//             ]),
//           ),
//         ]),
//       ),
//     );
//   }

//   Widget _buildCard(BuildContext context, int oi) {
//     final o          = orders[oi];
//     final orderId    = o['id'] as int;
//     final customer   = o['customers'] as Map? ?? {};
//     final ship       = shipments[orderId];
//     final isSelected = selectedOrderIndex == oi;
//     final isBusy     = _assigning.contains(orderId);

//     final orderDate = DateTime.tryParse(o['order_date']?.toString() ?? '');
//     final orderTime = orderDate != null
//         ? "${orderDate.toLocal().hour.toString().padLeft(2, '0')}:${orderDate.toLocal().minute.toString().padLeft(2, '0')}"
//         : "--:--";

//     final ost = _orderStyle(o['status']);
//     final sst = _shipStyle(ship?['status']);
//     final driverName = ship?['driver']?['name']?.toString();
//     final hasCoords  = double.tryParse(customer['latitude']?.toString() ?? '') != null;

//     return GestureDetector(
//       onTap: () {
//         final was = selectedOrderIndex == oi;
//         setState(() => selectedOrderIndex = was ? null : oi);
//         if (!was) _flyTo(o);
//       },
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         margin: const EdgeInsets.only(bottom: 10),
//         padding: const EdgeInsets.all(14),
//         decoration: BoxDecoration(
//           color: const Color(0xFF161B27),
//           borderRadius: BorderRadius.circular(18),
//           border: Border.all(
//             color: isSelected ? _cyan.withOpacity(0.5) : const Color(0xFF222840),
//             width: isSelected ? 1.5 : 1),
//           boxShadow: isSelected
//               ? [BoxShadow(color: _cyan.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))]
//               : [],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   width: 42, height: 42,
//                   decoration: BoxDecoration(
//                     color: isSelected ? _cyanBg : const Color(0xFF0F1117),
//                     borderRadius: BorderRadius.circular(12)),
//                   child: Icon(Icons.delivery_dining_rounded,
//                     color: isSelected ? _cyan : const Color(0xFF4A5568), size: 20)),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(children: [
//                         Text("#$orderId", style: const TextStyle(
//                           color: _amber, fontSize: 12, fontWeight: FontWeight.w700)),
//                         const SizedBox(width: 6),
//                         Text(orderTime, style: const TextStyle(
//                           color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
//                         if (hasCoords) ...[
//                           const SizedBox(width: 6),
//                           Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                             decoration: BoxDecoration(color: _cyanBg, borderRadius: BorderRadius.circular(5)),
//                             child: Row(mainAxisSize: MainAxisSize.min, children: const [
//                               Icon(Icons.location_on_rounded, size: 9, color: _cyan),
//                               SizedBox(width: 3),
//                               Text("On map", style: TextStyle(
//                                 color: _cyan, fontSize: 9, fontWeight: FontWeight.w600)),
//                             ]),
//                           ),
//                         ],
//                       ]),
//                       const SizedBox(height: 3),
//                       Text(customer['name'] ?? 'Unknown', style: const TextStyle(
//                         color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
//                       const SizedBox(height: 2),
//                       Text(customer['address'] ?? customer['phone'] ?? '—',
//                         style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
//                         maxLines: 1, overflow: TextOverflow.ellipsis),
//                     ],
//                   ),
//                 ),
//                 // Order status badge (read-only, from orders table)
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: ost['bg'], borderRadius: BorderRadius.circular(9),
//                     border: Border.all(color: (ost['color'] as Color).withOpacity(0.3), width: 1)),
//                   child: Row(mainAxisSize: MainAxisSize.min, children: [
//                     Icon(ost['icon'], size: 11, color: ost['color']),
//                     const SizedBox(width: 4),
//                     Text(_capitalize(o['status'] ?? ''), style: TextStyle(
//                       color: ost['color'], fontSize: 10, fontWeight: FontWeight.w700)),
//                   ]),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             const Divider(color: Color(0xFF222840), height: 1),
//             const SizedBox(height: 12),
//             Row(children: [
//               // Shipment badge
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: sst['bg'], borderRadius: BorderRadius.circular(9),
//                   border: Border.all(color: (sst['color'] as Color).withOpacity(0.35), width: 1)),
//                 child: Row(mainAxisSize: MainAxisSize.min, children: [
//                   Icon(sst['icon'], size: 12, color: sst['color']),
//                   const SizedBox(width: 5),
//                   Text(sst['label'], style: TextStyle(
//                     color: sst['color'], fontSize: 11, fontWeight: FontWeight.w700)),
//                 ]),
//               ),
//               const SizedBox(width: 8),
//               if (driverName != null)
//                 Expanded(child: Row(children: [
//                   const Icon(Icons.person_rounded, size: 13, color: Color(0xFF64748B)),
//                   const SizedBox(width: 3),
//                   Expanded(child: Text(driverName,
//                     maxLines: 1, overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600))),
//                 ]))
//               else
//                 const Spacer(),
//               // Assign / reassign
//               // Cancel assignment (hard delete)
//               if (ship != null)
//                 GestureDetector(
//                   onTap: isBusy ? null : () => _confirmCancel(context, oi),
//                   child: Container(
//                     padding: const EdgeInsets.all(8),
//                     margin: const EdgeInsets.only(right: 8),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF2D0A0A),
//                       borderRadius: BorderRadius.circular(9),
//                       border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4), width: 1)),
//                     child: const Icon(Icons.person_remove_rounded, size: 15, color: Color(0xFFEF4444)),
//                   ),
//                 ),
//               // Assign / reassign
//               GestureDetector(
//                 onTap: isBusy ? null : () => _showAssignSheet(context, oi),
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFF1E1B4B),
//                     borderRadius: BorderRadius.circular(9),
//                     border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.5), width: 1)),
//                   child: isBusy
//                       ? const SizedBox(width: 60, height: 14, child: Center(
//                           child: SizedBox(width: 13, height: 13,
//                             child: CircularProgressIndicator(strokeWidth: 1.6, color: Color(0xFF6C63FF)))))
//                       : Row(mainAxisSize: MainAxisSize.min, children: [
//                           Icon(ship == null ? Icons.person_add_alt_1_rounded : Icons.swap_horiz_rounded,
//                             size: 13, color: const Color(0xFF8B85FF)),
//                           const SizedBox(width: 5),
//                           Text(ship == null ? "Assign" : "Reassign", style: const TextStyle(
//                             color: Color(0xFF8B85FF), fontSize: 11.5, fontWeight: FontWeight.w700)),
//                         ]),
//                 ),
//               ),
//             ]),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/supabase_service.dart';
import '../helpers/cached_tile_provider.dart';

/// ADMIN point-of-view. The day's delivery orders on a map, assign each to a
/// driver (incl. yourself), filter by driver, expand order details, and watch
/// live driver positions. Never touches `orders.status`.
class DriverShipmentPage extends StatefulWidget {
  @override
  State<DriverShipmentPage> createState() => _DriverShipmentPageState();
}

class _DriverShipmentPageState extends State<DriverShipmentPage> {
  List orders = [];
  Map<int, Map<String, dynamic>> shipments = {}; // order_id -> shipment
  List users = [];
  List driverLocs = [];
  bool loading = true;

  DateTime selectedDate = DateTime.now();
  String? filterDriverId; // null = all drivers
  int? selectedOrderIndex;

  final Set<int> _assigning = {};

  final MapController _mapController = MapController();
  Timer? _liveTimer;

  static const LatLng _depot  = LatLng(-7.586647230136144, 110.94508655273896);
  static const Color  _cyan   = Color(0xFF06B6D4);
  static const Color  _cyanBg = Color(0xFF0C2A3A);
  static const Color  _amber  = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _load();
    _liveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshLive());
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future _load() async {
    setState(() { loading = true; selectedOrderIndex = null; });
    final data = await SupabaseService.getOrders(
      date: selectedDate, deliveryType: 'delivery', withItems: true, pageSize: 100);
    final ids = <int>[for (final o in data) o['id'] as int];
    final results = await Future.wait([
      SupabaseService.getShipmentsByOrderIds(ids),
      SupabaseService.getActiveUsers(),
      SupabaseService.getDriverLocations(),
    ]);
    if (!mounted) return;
    setState(() {
      orders     = data;
      shipments  = results[0] as Map<int, Map<String, dynamic>>;
      users      = results[1] as List;
      driverLocs = results[2] as List;
      loading    = false;
    });
    final first = _firstWithCoords();
    if (first != null) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _mapController.move(first, 13);
      });
    }
  }

  Future _refreshLive() async {
    if (orders.isEmpty) {
      final locs = await SupabaseService.getDriverLocations();
      if (mounted) setState(() => driverLocs = locs);
      return;
    }
    final ids = <int>[for (final o in orders) o['id'] as int];
    final results = await Future.wait([
      SupabaseService.getShipmentsByOrderIds(ids),
      SupabaseService.getDriverLocations(),
    ]);
    if (!mounted) return;
    setState(() {
      shipments  = results[0] as Map<int, Map<String, dynamic>>;
      driverLocs = results[1] as List;
    });
  }

  // Order indices visible under the current driver filter.
  List<int> get _visIdx {
    final list = <int>[];
    for (int i = 0; i < orders.length; i++) {
      if (filterDriverId == null) { list.add(i); continue; }
      final ship = shipments[orders[i]['id'] as int];
      if (ship != null && ship['driver_id']?.toString() == filterDriverId) list.add(i);
    }
    return list;
  }

  LatLng? _firstWithCoords() {
    for (final o in orders) {
      final c = o['customers'];
      final lat = double.tryParse(c?['latitude']?.toString() ?? '');
      final lng = double.tryParse(c?['longitude']?.toString() ?? '');
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  void _flyTo(Map order) {
    final c = order['customers'];
    final lat = double.tryParse(c?['latitude']?.toString() ?? '');
    final lng = double.tryParse(c?['longitude']?.toString() ?? '');
    if (lat != null && lng != null) _mapController.move(LatLng(lat, lng), 15);
  }

  // ── Assign / cancel ──────────────────────────────────────────────────────

  void _showAssignSheet(BuildContext context, int oi) {
    final order = orders[oi];
    final orderId = order['id'] as int;
    final currentDriverId = shipments[orderId]?['driver_id']?.toString();

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161B27),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.fromBorderSide(BorderSide(color: Color(0xFF222840), width: 1))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFF2A3040), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              const Text("Assign driver", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text("#$orderId", style: const TextStyle(color: _amber, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),
          if (users.isEmpty)
            const Padding(padding: EdgeInsets.all(24),
              child: Text("No active users found", style: TextStyle(color: Color(0xFF4A5568), fontSize: 13))),
          ...users.map((u) {
            final uid = u['id'].toString();
            final isCurrent = uid == currentDriverId;
            final initials = _initials(u['name']?.toString() ?? '?');
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)))),
              title: Text(u['name']?.toString() ?? '—', style: TextStyle(
                color: isCurrent ? _cyan : Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text((u['role']?.toString() ?? '').toUpperCase(),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              trailing: isCurrent
                  ? const Icon(Icons.check_circle_rounded, color: _cyan, size: 20)
                  : const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF4A5568), size: 13),
              onTap: () { Navigator.pop(context); _assign(oi, uid); },
            );
          }),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Future _assign(int oi, String driverId) async {
    final orderId = orders[oi]['id'] as int;
    if (_assigning.contains(orderId)) return;
    setState(() => _assigning.add(orderId));
    try {
      final ship = await SupabaseService.assignShipment(orderId: orderId, driverId: driverId);
      // fetch driver name for immediate display (loop avoids firstWhere type trap)
      Map<String, dynamic>? u;
      for (final x in users) {
        if (x['id'].toString() == driverId) { u = Map<String, dynamic>.from(x); break; }
      }
      if (u != null) ship['driver'] = {'id': u['id'], 'name': u['name']};
      setState(() => shipments[orderId] = Map<String, dynamic>.from(ship));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to assign: $e'), backgroundColor: const Color(0xFF2D0A0A)));
      }
    } finally {
      if (mounted) setState(() => _assigning.remove(orderId));
    }
  }

  Future _confirmCancel(BuildContext context, int oi) async {
    final orderId = orders[oi]['id'] as int;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancel assignment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text('Remove the shipment for order #$orderId? This deletes it from the database.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep', style: TextStyle(color: Color(0xFF94A3B8)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) _cancelAssign(oi);
  }

  Future _cancelAssign(int oi) async {
    final orderId = orders[oi]['id'] as int;
    if (_assigning.contains(orderId)) return;
    setState(() => _assigning.add(orderId));
    try {
      await SupabaseService.deleteShipment(orderId);
      setState(() => shipments.remove(orderId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to cancel: $e'), backgroundColor: const Color(0xFF2D0A0A)));
      }
    } finally {
      if (mounted) setState(() => _assigning.remove(orderId));
    }
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context, initialDate: selectedDate,
      firstDate: DateTime(2020), lastDate: DateTime(2200),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: _cyan, surface: Color(0xFF161B27), onSurface: Colors.white),
          dialogBackgroundColor: const Color(0xFF161B27)),
        child: child!),
    );
    if (picked != null) { setState(() => selectedDate = picked); _load(); }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _initials(String name) => name.trim().split(RegExp(r'\s+')).take(2)
      .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

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

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Map<String, dynamic> _orderStyle(String? s) {
    switch (s) {
      case 'pending':   return {'color': const Color(0xFFF59E0B), 'bg': const Color(0xFF2D1F0A), 'icon': Icons.hourglass_empty_rounded};
      case 'prepared':  return {'color': const Color(0xFF06B6D4), 'bg': const Color(0xFF0C2A3A), 'icon': Icons.kitchen_rounded};
      case 'paid':      return {'color': const Color(0xFF6C63FF), 'bg': const Color(0xFF1E1B4B), 'icon': Icons.payments_rounded};
      case 'delivered': return {'color': const Color(0xFF10B981), 'bg': const Color(0xFF062318), 'icon': Icons.task_alt_rounded};
      case 'cancelled': return {'color': const Color(0xFFEF4444), 'bg': const Color(0xFF2D0A0A), 'icon': Icons.cancel_outlined};
      default:          return {'color': const Color(0xFF94A3B8), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.circle_outlined};
    }
  }

  Map<String, dynamic> _shipStyle(String? s) {
    switch (s) {
      case 'assigned':  return {'color': const Color(0xFF94A3B8), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.assignment_ind_rounded, 'label': 'Assigned'};
      case 'en_route':  return {'color': const Color(0xFF3B82F6), 'bg': const Color(0xFF0B1D3A), 'icon': Icons.two_wheeler_rounded,     'label': 'En route'};
      case 'arrived':   return {'color': const Color(0xFF8B5CF6), 'bg': const Color(0xFF1C1030), 'icon': Icons.pin_drop_rounded,       'label': 'Arrived'};
      case 'completed': return {'color': const Color(0xFF10B981), 'bg': const Color(0xFF062318), 'icon': Icons.check_circle_rounded,   'label': 'Completed'};
      case 'failed':    return {'color': const Color(0xFFEF4444), 'bg': const Color(0xFF2D0A0A), 'icon': Icons.error_outline_rounded,  'label': 'Failed'};
      case 'cancelled': return {'color': const Color(0xFF64748B), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.block_rounded,          'label': 'Cancelled'};
      default:          return {'color': const Color(0xFF4A5568), 'bg': const Color(0xFF1A1F2E), 'icon': Icons.help_outline_rounded,   'label': 'Unassigned'};
    }
  }

  bool _isStale(dynamic updatedAt) {
    final t = DateTime.tryParse(updatedAt?.toString() ?? '');
    if (t == null) return true;
    return DateTime.now().toUtc().difference(t.toUtc()).inSeconds > 30;
  }

  // ── Markers ────────────────────────────────────────────────────────────────

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final vis = _visIdx.toSet();

    markers.add(Marker(
      point: _depot, width: 48, height: 58,
      child: Column(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFF2D1200), shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF97316), width: 2),
            boxShadow: [BoxShadow(color: const Color(0xFFF97316).withOpacity(0.4), blurRadius: 12)]),
          child: const Icon(Icons.store_rounded, color: Color(0xFFF97316), size: 18)),
        Container(width: 2, height: 12, color: const Color(0xFFF97316)),
        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle)),
      ]),
    ));

    for (int i = 0; i < orders.length; i++) {
      if (!vis.contains(i)) continue;
      final o = orders[i];
      final c = o['customers'];
      final lat = double.tryParse(c?['latitude']?.toString() ?? '');
      final lng = double.tryParse(c?['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      final orderId = o['id'] as int;
      final ship = shipments[orderId];
      final isSelected = selectedOrderIndex == i;
      final baseColor = ship != null
          ? _shipStyle(ship['status'])['color'] as Color
          : _orderStyle(o['status'])['color'] as Color;
      final dotColor = isSelected ? _cyan : baseColor;

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: isSelected ? 56 : 40, height: isSelected ? 66 : 50,
        child: GestureDetector(
          onTap: () {
            setState(() => selectedOrderIndex = selectedOrderIndex == i ? null : i);
            if (selectedOrderIndex == i) _flyTo(o);
          },
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 44 : 32, height: isSelected ? 44 : 32,
              decoration: BoxDecoration(color: isSelected ? _cyanBg : const Color(0xFF161B27), shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: isSelected ? 2.5 : 1.5),
                boxShadow: [BoxShadow(color: dotColor.withOpacity(isSelected ? 0.5 : 0.2), blurRadius: isSelected ? 16 : 6)]),
              child: Icon(Icons.two_wheeler_rounded, color: dotColor, size: isSelected ? 22 : 16)),
            Container(width: isSelected ? 3 : 2, height: isSelected ? 14 : 10, color: dotColor),
            Container(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          ]),
        ),
      ));
    }

    for (final d in driverLocs) {
      if (filterDriverId != null && d['driver_id']?.toString() != filterDriverId) continue;
      final lat = double.tryParse(d['latitude']?.toString() ?? '');
      final lng = double.tryParse(d['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;
      final stale = _isStale(d['updated_at']);
      final name = (d['users']?['name']?.toString() ?? 'Driver');
      final col = stale ? const Color(0xFF64748B) : const Color(0xFF10B981);

      markers.add(Marker(
        point: LatLng(lat, lng), width: 90, height: 62,
        child: Column(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: const Color(0xFF062318), shape: BoxShape.circle,
              border: Border.all(color: col, width: 2.5),
              boxShadow: [BoxShadow(color: col.withOpacity(stale ? 0.2 : 0.55), blurRadius: stale ? 6 : 16)]),
            child: Icon(Icons.two_wheeler_rounded, color: col, size: 18)),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xE6161B27), borderRadius: BorderRadius.circular(6),
              border: Border.all(color: col.withOpacity(0.5), width: 1)),
            child: Text(stale ? '$name · idle' : name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.w700))),
        ]),
      ));
    }

    return markers;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final online = driverLocs.where((d) => !_isStale(d['updated_at'])).length;
    final vis = _visIdx;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            flex: 5,
            child: Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(initialCenter: _depot, initialZoom: 12,
                    interactionOptions: InteractionOptions(flags: InteractiveFlag.all)),
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
                  child: Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xE6161B27), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A3040), width: 1)),
                    child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF94A3B8), size: 20)),
                ),
              ),

              Positioned(top: 16, left: 68, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xE6161B27), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A3040), width: 1)),
                  child: Row(children: [
                    const Icon(Icons.two_wheeler_rounded, color: _cyan, size: 16),
                    const SizedBox(width: 8),
                    const Text("Driver Shipments", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(width: 8, height: 8, decoration: BoxDecoration(
                      color: online > 0 ? const Color(0xFF10B981) : const Color(0xFF64748B), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text("$online live", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ]),
                ),
              ),

              Positioned(bottom: 28, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(4)),
                  child: const Text("© OpenStreetMap contributors", style: TextStyle(color: Colors.white70, fontSize: 9))),
              ),
            ]),
          ),

          Expanded(
            flex: 6,
            child: Column(children: [
              // Date bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: GestureDetector(
                  onTap: () => _pickDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFF161B27), borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFF222840), width: 1)),
                    child: Row(children: [
                      Container(width: 30, height: 30,
                        decoration: BoxDecoration(color: _cyanBg, borderRadius: BorderRadius.circular(8)),
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

              // Driver filter
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _filterChip('All drivers', null),
                    ...users.map((u) => _filterChip(u['name']?.toString() ?? '—', u['id'].toString())),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              Expanded(
                child: loading
                    ? const Center(child: SizedBox(width: 32, height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: _cyan)))
                    : vis.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.two_wheeler_outlined, color: Color(0xFF2A3040), size: 52),
                            const SizedBox(height: 12),
                            Text(filterDriverId == null ? "No deliveries on this date" : "Nothing for this driver",
                              style: const TextStyle(color: Color(0xFF4A5568), fontSize: 14)),
                          ]))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: vis.length,
                            itemBuilder: (ctx, idx) => _buildCard(ctx, vis[idx])),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _filterChip(String label, String? driverId) {
    final selected = filterDriverId == driverId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() { filterDriverId = driverId; selectedOrderIndex = null; }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? _cyanBg : const Color(0xFF161B27),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? _cyan.withOpacity(0.5) : const Color(0xFF222840), width: 1)),
          child: Text(label, style: TextStyle(
            color: selected ? _cyan : const Color(0xFF94A3B8), fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, int oi) {
    final o = orders[oi];
    final orderId = o['id'] as int;
    final customer = o['customers'] as Map? ?? {};
    final items = (o['order_items'] as List?) ?? [];
    final ship = shipments[orderId];
    final isSelected = selectedOrderIndex == oi;
    final isBusy = _assigning.contains(orderId);

    final orderDate = DateTime.tryParse(o['order_date']?.toString() ?? '');
    final orderTime = orderDate != null
        ? "${orderDate.toLocal().hour.toString().padLeft(2, '0')}:${orderDate.toLocal().minute.toString().padLeft(2, '0')}"
        : "--:--";

    final ost = _orderStyle(o['status']);
    final sst = _shipStyle(ship?['status']);
    final driverName = ship?['driver']?['name']?.toString();
    final hasCoords = double.tryParse(customer['latitude']?.toString() ?? '') != null;

    final total = double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0;
    final delivery = double.tryParse(o['delivery_price']?.toString() ?? '0') ?? 0;
    final subtotal = total - delivery;

    return GestureDetector(
      onTap: () {
        final was = selectedOrderIndex == oi;
        setState(() => selectedOrderIndex = was ? null : oi);
        if (!was) _flyTo(o);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161B27), borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? _cyan.withOpacity(0.5) : const Color(0xFF222840), width: isSelected ? 1.5 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: _cyan.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))] : []),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 42, height: 42,
                  decoration: BoxDecoration(color: isSelected ? _cyanBg : const Color(0xFF0F1117), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.two_wheeler_rounded, color: isSelected ? _cyan : const Color(0xFF4A5568), size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text("#$orderId", style: const TextStyle(color: _amber, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Text(orderTime, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
                    if (hasCoords) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _cyanBg, borderRadius: BorderRadius.circular(5)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [
                          Icon(Icons.location_on_rounded, size: 9, color: _cyan),
                          SizedBox(width: 3),
                          Text("On map", style: TextStyle(color: _cyan, fontSize: 9, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(customer['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(customer['address'] ?? customer['phone'] ?? '—',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(color: ost['bg'], borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: (ost['color'] as Color).withOpacity(0.3), width: 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(ost['icon'], size: 11, color: ost['color']),
                    const SizedBox(width: 4),
                    Text(_capitalize(o['status'] ?? ''), style: TextStyle(color: ost['color'], fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF222840), height: 1),
              const SizedBox(height: 12),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: sst['bg'], borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: (sst['color'] as Color).withOpacity(0.35), width: 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(sst['icon'], size: 12, color: sst['color']),
                    const SizedBox(width: 5),
                    Text(sst['label'], style: TextStyle(color: sst['color'], fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 8),
                if (driverName != null)
                  Expanded(child: Row(children: [
                    const Icon(Icons.person_rounded, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Expanded(child: Text(driverName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600))),
                  ]))
                else const Spacer(),
                if (ship != null)
                  GestureDetector(
                    onTap: isBusy ? null : () => _confirmCancel(context, oi),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: const Color(0xFF2D0A0A), borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4), width: 1)),
                      child: const Icon(Icons.person_remove_rounded, size: 15, color: Color(0xFFEF4444)),
                    ),
                  ),
                GestureDetector(
                  onTap: isBusy ? null : () => _showAssignSheet(context, oi),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: const Color(0xFF1E1B4B), borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.5), width: 1)),
                    child: isBusy
                        ? const SizedBox(width: 60, height: 14, child: Center(
                            child: SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.6, color: Color(0xFF6C63FF)))))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(ship == null ? Icons.person_add_alt_1_rounded : Icons.swap_horiz_rounded, size: 13, color: const Color(0xFF8B85FF)),
                            const SizedBox(width: 5),
                            Text(ship == null ? "Assign" : "Reassign", style: const TextStyle(color: Color(0xFF8B85FF), fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ]),
                  ),
                ),
              ]),
            ]),
          ),

          // Expanded order detail (items + totals)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpanded(items, subtotal, delivery, total),
            crossFadeState: isSelected ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ]),
      ),
    );
  }

  Widget _buildExpanded(List items, double subtotal, double delivery, double total) {
    return Column(children: [
      const Divider(color: Color(0xFF222840), height: 1, indent: 14, endIndent: 14),
      if (items.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("ITEMS", style: TextStyle(color: Color(0xFF4A5568), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            Text("${items.where((i) => i['is_prepared'] == true).length}/${items.length} prepared",
              style: TextStyle(
                color: items.every((i) => i['is_prepared'] == true) ? const Color(0xFF10B981) : const Color(0xFF4A5568),
                fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
        ...items.map((item) {
          final product = item['products'] as Map? ?? {};
          final variant = item['product_variants'] as Map?;
          final qty = double.tryParse(item['quantity'].toString()) ?? 0;
          final price = double.tryParse(item['sell_price'].toString()) ?? 0;
          final prepared = item['is_prepared'] == true;
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: prepared ? const Color(0xFF10B981) : const Color(0xFF2A3040), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product['name'] ?? '—', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                if (variant != null && variant['name'] != null && variant['name'] != 'default')
                  Text(variant['name'], style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 10)),
              ])),
              Text("${qty % 1 == 0 ? qty.toInt() : qty} ${product['unit'] ?? ''}",
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              const SizedBox(width: 12),
              Text("Rp ${_formatPrice(qty * price)}", style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          );
        }),
      ],
      Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF0F1117), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF222840), width: 1)),
        child: Column(children: [
          _totalRow("Subtotal", subtotal, const Color(0xFFCBD5E1)),
          const SizedBox(height: 8),
          _totalRow("Delivery fee", delivery, _cyan),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Color(0xFF222840), height: 1)),
          _totalRow("Total", total, _amber, large: true),
        ]),
      ),
    ]);
  }

  Widget _totalRow(String label, double amount, Color valueColor, {bool large = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: large ? Colors.white : const Color(0xFF64748B),
        fontSize: large ? 14 : 12, fontWeight: large ? FontWeight.w800 : FontWeight.w500)),
      Text("Rp ${_formatPrice(amount)}", style: TextStyle(color: valueColor, fontSize: large ? 15 : 12, fontWeight: FontWeight.w800)),
    ]);
  }
}