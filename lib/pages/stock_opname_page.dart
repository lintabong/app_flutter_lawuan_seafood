
// ═══════════════════════════════════════════════════════════════════
// lib/pages/stock_opname_page.dart  (file BARU)
//
// Stock opname: pilih product → semua variant tampil dengan stok
// sistem → isi stok fisik hasil hitung → selisih (susut/lebih)
// terlihat live per baris → submit hanya mengirim yang berubah.
//
// Jangan lupa jalankan stock_opname_rpc.sql dulu, dan daftarkan
// halaman ini di main_menu.dart.
//
// ─────────────────────────────────────────────────────────────────
// TAMBAHKAN 2 METHOD INI KE lib/services/supabase_service.dart
// (getProductsForProductConversion sudah ada dari fitur product
//  conversion — halaman ini memakainya juga karena butuh buy_price):
// ─────────────────────────────────────────────────────────────────
//
//   /// RPC stock_opname.
//   /// items: [{'variant_id': 12, 'physical_stock': 3.5}, ...]
//   /// Return: { session_id, items_adjusted, total_value_diff }
//   static Future<Map<String, dynamic>> stockOpname({
//     required List<Map<String, dynamic>> items,
//     String? note,
//   }) async {
//     final response = await supabase.rpc(
//       'stock_opname',
//       params: {
//         'p_items': items,
//         'p_note':
//             (note != null && note.trim().isNotEmpty) ? note.trim() : null,
//         'p_created_by': currentUserId,
//       },
//     );
//     if (response == null || (response as List).isEmpty) {
//       throw Exception('No response from stock_opname');
//     }
//     return Map<String, dynamic>.from(response.first);
//   }
//
//   /// Riwayat opname terakhir (per item).
//   static Future<List<dynamic>> getStockOpnameLedger(
//       {int limit = 20}) async {
//     final response = await supabase
//         .from('stock_opname_ledger')
//         .select('''
//           id, session_id, stock_before, stock_after, difference,
//           unit_cost, value_diff, note, created_at,
//           products(id, name, unit),
//           product_variants(id, name, unit)
//         ''')
//         .order('created_at', ascending: false)
//         .limit(limit);
//     return response;
//   }
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class StockOpnamePage extends StatefulWidget {
  const StockOpnamePage({super.key});

  @override
  State<StockOpnamePage> createState() => _StockOpnamePageState();
}

class _StockOpnamePageState extends State<StockOpnamePage> {
  // ── Data ─────────────────────────────────────────────────
  List _products = [];
  List _ledger = [];
  bool _loading = true;
  bool _submitting = false;

  Map<String, dynamic>? _selectedProduct;

  /// Controller stok fisik per variant id.
  final Map<int, TextEditingController> _physicalCtrls = {};
  final TextEditingController _noteCtrl = TextEditingController();

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    for (final c in _physicalCtrls.values) {
      c.dispose();
    }
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      SupabaseService.getProductsForProductConversion(),
      SupabaseService.getStockOpnameLedger(limit: 15),
    ]);
    if (!mounted) return;
    setState(() {
      _products = results[0];
      _ledger = results[1];
      _loading = false;
    });
  }

  Future<void> _refreshAfterOpname() async {
    final productId = _selectedProduct?['id'] as int?;
    final results = await Future.wait([
      SupabaseService.getProductsForProductConversion(),
      SupabaseService.getStockOpnameLedger(limit: 15),
    ]);
    if (!mounted) return;
    setState(() {
      _products = results[0];
      _ledger = results[1];
      if (productId != null) {
        final fresh = _products
            .cast<Map<String, dynamic>>()
            .where((p) => p['id'] == productId)
            .toList();
        _selectedProduct = fresh.isNotEmpty ? fresh.first : null;
      }
      _rebuildControllers();
    });
  }

  // ── Controllers per variant ───────────────────────────────
  void _rebuildControllers() {
    for (final c in _physicalCtrls.values) {
      c.dispose();
    }
    _physicalCtrls.clear();
    for (final v in _variants) {
      final id = v['id'] as int;
      _physicalCtrls[id] =
          TextEditingController(text: _fmtQty(_num(v['stock'])));
    }
  }

  // ── Computed ──────────────────────────────────────────────
  double _num(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

  List<Map<String, dynamic>> get _variants {
    if (_selectedProduct == null) return [];
    final raw = _selectedProduct!['product_variants'];
    if (raw == null) return [];
    final list = List<Map<String, dynamic>>.from(raw as List);
    list.sort((a, b) {
      if (a['name'] == 'default') return -1;
      if (b['name'] == 'default') return 1;
      return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
    });
    return list;
  }

  /// Selisih fisik − sistem untuk satu variant (null kalau input invalid).
  double? _diffOf(Map<String, dynamic> v) {
    final ctrl = _physicalCtrls[v['id']];
    if (ctrl == null) return null;
    final physical = double.tryParse(ctrl.text);
    if (physical == null) return null;
    return physical - _num(v['stock']);
  }

  /// Item yang berubah (dikirim ke RPC).
  List<Map<String, dynamic>> get _changedItems {
    final items = <Map<String, dynamic>>[];
    for (final v in _variants) {
      final ctrl = _physicalCtrls[v['id']];
      if (ctrl == null) continue;
      final physical = double.tryParse(ctrl.text);
      if (physical == null || physical < 0) continue;
      if (physical == _num(v['stock'])) continue;
      items.add({
        'variant_id': v['id'],
        'physical_stock': physical,
      });
    }
    return items;
  }

  /// Estimasi total nilai selisih (rupiah) untuk preview.
  double get _estTotalValueDiff {
    double total = 0;
    for (final v in _variants) {
      final diff = _diffOf(v);
      if (diff == null || diff == 0) continue;
      total += diff * _num(v['buy_price']);
    }
    return total;
  }

  bool get _canSubmit =>
      _selectedProduct != null && _changedItems.isNotEmpty && !_submitting;

  // ── Helpers ───────────────────────────────────────────────
  String _fmtQty(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);

  String _fmtDiff(double d) {
    final s = _fmtQty(d.abs());
    return d > 0 ? '+$s' : '-$s';
  }

  String _fmtPrice(double price) {
    final str = price.abs().round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return (price < 0 ? '-' : '') + buffer.toString();
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '-';
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}';
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor:
          success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Actions ───────────────────────────────────────────────
  void _selectProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OpnameProductPickerSheet(
        products: _products,
        onSelect: (p) => setState(() {
          _selectedProduct = p;
          _rebuildControllers();
        }),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _submitting = true);
    try {
      final result = await SupabaseService.stockOpname(
        items: _changedItems,
        note: _noteCtrl.text,
      );

      await _refreshAfterOpname();

      if (mounted) {
        final adjusted = result['items_adjusted'] ?? 0;
        final valueDiff = _num(result['total_value_diff']);
        _snack(
          'Opname tersimpan ✓  $adjusted item, '
          'selisih Rp ${_fmtPrice(valueDiff)}',
          success: true,
        );
        _noteCtrl.clear();
      }
    } catch (e) {
      _snack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF6C63FF),
                ),
              )
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildProductSection(),
                          if (_selectedProduct != null) ...[
                            const SizedBox(height: 20),
                            _buildCountSection(),
                            const SizedBox(height: 20),
                            _buildSummaryCard(),
                            const SizedBox(height: 20),
                            _buildNoteSection(),
                          ],
                          const SizedBox(height: 20),
                          _buildLedgerSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton:
          (_loading || _selectedProduct == null) ? null : _buildSubmitButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Stock Opname",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "Sesuaikan stok sistem dengan hitungan fisik",
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  // ── Product ───────────────────────────────────────────────
  Widget _buildProductSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PRODUCT'),
        GestureDetector(
          onTap: _selectProductSheet,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedProduct != null
                    ? const Color(0xFF6C63FF).withOpacity(0.4)
                    : const Color(0xFF222840),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B4B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fact_check_rounded,
                      color: Color(0xFF6C63FF), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedProduct == null
                      ? const Text(
                          'Select product to count...',
                          style: TextStyle(
                              color: Color(0xFF4A5568), fontSize: 14),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedProduct!['name'] ?? '-',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${_variants.length} variant'
                              '${_variants.length == 1 ? '' : 's'} to count',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF2A3040), size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Count rows ────────────────────────────────────────────
  Widget _buildCountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PHYSICAL COUNT'),
        ..._variants.map((v) {
          final id = v['id'] as int;
          final ctrl = _physicalCtrls[id];
          if (ctrl == null) return const SizedBox.shrink();

          final systemStock = _num(v['stock']);
          final diff = _diffOf(v);
          final hasDiff = diff != null && diff != 0;
          final isDefault = v['name'] == 'default';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasDiff
                    ? (diff < 0
                        ? const Color(0xFFEF4444).withOpacity(0.4)
                        : const Color(0xFF10B981).withOpacity(0.4))
                    : const Color(0xFF222840),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDefault
                        ? const Color(0xFF062318)
                        : const Color(0xFF1A1830),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                      isDefault ? Icons.star_rounded : Icons.tune_rounded,
                      color: isDefault
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6C63FF),
                      size: 15),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v['name'] ?? '-',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sistem: ${_fmtQty(systemStock)} ${v['unit'] ?? ''}',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Input fisik
                Container(
                  width: 84,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1117),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF222840), width: 1),
                  ),
                  child: TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                // Badge selisih
                SizedBox(
                  width: 64,
                  child: Center(
                    child: !hasDiff
                        ? const Text('—',
                            style: TextStyle(
                                color: Color(0xFF2A3040), fontSize: 13))
                        : Text(
                            _fmtDiff(diff),
                            style: TextStyle(
                              color: diff < 0
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Summary ───────────────────────────────────────────────
  Widget _buildSummaryCard() {
    final changed = _changedItems.length;
    final valueDiff = _estTotalValueDiff;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222840), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$changed item berubah',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Estimasi nilai selisih',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
          Text(
            'Rp ${_fmtPrice(valueDiff)}',
            style: TextStyle(
              color: valueDiff < 0
                  ? const Color(0xFFEF4444)
                  : valueDiff > 0
                      ? const Color(0xFF10B981)
                      : const Color(0xFF64748B),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Note ──────────────────────────────────────────────────
  Widget _buildNoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('NOTE (OPTIONAL)'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF222840), width: 1),
          ),
          child: TextField(
            controller: _noteCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'e.g. opname mingguan, es mencair...',
              hintStyle: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // ── Ledger ────────────────────────────────────────────────
  Widget _buildLedgerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('RECENT ADJUSTMENTS'),
        if (_ledger.isEmpty)
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF222840), width: 1),
            ),
            child: const Center(
              child: Text(
                'No stock adjustments yet',
                style: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
              ),
            ),
          )
        else
          ..._ledger.map((l) {
            final entry = l as Map<String, dynamic>;
            final productName = entry['products']?['name'] ?? '-';
            final variantName = entry['product_variants']?['name'] ?? '-';
            final before = _num(entry['stock_before']);
            final after = _num(entry['stock_after']);
            final diff = _num(entry['difference']);
            final valueDiff = _num(entry['value_diff']);
            final isLoss = diff < 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161B27),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF222840), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isLoss
                          ? const Color(0xFF2A0B0B)
                          : const Color(0xFF062318),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isLoss
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded,
                      color: isLoss
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$productName · $variantName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_fmtQty(before)} → ${_fmtQty(after)}'
                          '  ·  ${_fmtDate(entry['created_at']?.toString())}',
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _fmtDiff(diff),
                        style: TextStyle(
                          color: isLoss
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Rp ${_fmtPrice(valueDiff)}',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ── Submit ────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    final enabled = _canSubmit;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: enabled ? _submit : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF222840), Color(0xFF222840)],
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    'Save Opname (${_changedItems.length})',
                    style: TextStyle(
                      color:
                          enabled ? Colors.white : const Color(0xFF4A5568),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Product Picker Sheet
// ═══════════════════════════════════════════════════════════════════
class _OpnameProductPickerSheet extends StatefulWidget {
  final List products;
  final void Function(Map<String, dynamic>) onSelect;

  const _OpnameProductPickerSheet({
    required this.products,
    required this.onSelect,
  });

  @override
  State<_OpnameProductPickerSheet> createState() =>
      _OpnameProductPickerSheetState();
}

class _OpnameProductPickerSheetState
    extends State<_OpnameProductPickerSheet> {
  String _search = '';

  List get _filtered => _search.isEmpty
      ? widget.products
      : widget.products
          .where((p) => p['name']
              .toString()
              .toLowerCase()
              .contains(_search.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161B27),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3040),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Product',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1117),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF222840)),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search products...',
                    hintStyle:
                        TextStyle(color: Color(0xFF4A5568), fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Color(0xFF4A5568), size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final p = _filtered[i] as Map<String, dynamic>;
                  final variantCount =
                      (p['product_variants'] as List?)?.length ?? 0;

                  return GestureDetector(
                    onTap: () {
                      widget.onSelect(p);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1117),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: const Color(0xFF222840)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B4B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory_2_rounded,
                                color: Color(0xFF6C63FF), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'] ?? '-',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '$variantCount variant'
                                  '${variantCount == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFF2A3040), size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}