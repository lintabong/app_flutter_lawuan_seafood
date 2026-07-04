
// ═══════════════════════════════════════════════════════════════════
// lib/pages/convert_product_page.dart  (file BARU)
//
// Konversi antar product: default A berkurang → default B bertambah,
// dengan penyusutan (qty out ≠ qty in) dan cost absorption (nilai
// rupiah ikut pindah, semua variant B di-reprice via WAC).
//
// Jangan lupa jalankan convert_product_rpc.sql dulu, dan daftarkan
// halaman ini di main_menu.dart seperti halaman lain.
//
// ─────────────────────────────────────────────────────────────────
// TAMBAHKAN 3 METHOD INI KE lib/services/supabase_service.dart:
// ─────────────────────────────────────────────────────────────────
//
//   /// Products + variant lengkap dengan buy_price — dipakai halaman
//   /// product conversion (perlu buy_price untuk preview WAC).
//   static Future<List<dynamic>> getProductsForProductConversion() async {
//     final response = await supabase
//         .from('products')
//         .select('''
//           id, name, unit,
//           product_variants(
//             id, name, unit, stock, buy_price,
//             conversion_factor, is_active
//           )
//         ''')
//         .eq('is_active', true)
//         .order('name');
//     return response;
//   }
//
//   /// RPC convert_product.
//   /// Return: { ledger_id, from_stock, to_stock, new_avg_cost }
//   static Future<Map<String, dynamic>> convertProduct({
//     required int fromProductId,
//     required int toProductId,
//     required double qtyFrom,
//     required double qtyTo,
//     String? note,
//   }) async {
//     final response = await supabase.rpc(
//       'convert_product',
//       params: {
//         'p_from_product_id': fromProductId,
//         'p_to_product_id': toProductId,
//         'p_qty_from': qtyFrom,
//         'p_qty_to': qtyTo,
//         'p_note':
//             (note != null && note.trim().isNotEmpty) ? note.trim() : null,
//         'p_created_by': currentUserId,
//       },
//     );
//     if (response == null || (response as List).isEmpty) {
//       throw Exception('No response from convert_product');
//     }
//     return Map<String, dynamic>.from(response.first);
//   }
//
//   /// Riwayat konversi product terakhir.
//   static Future<List<dynamic>> getProductConversionLedger(
//       {int limit = 10}) async {
//     final response = await supabase
//         .from('product_conversion_ledger')
//         .select('''
//           id, qty_from, qty_to, unit_cost, total_value,
//           new_avg_cost, note, created_at,
//           from_product:products!product_conversion_ledger_from_product_id_fkey(id, name),
//           to_product:products!product_conversion_ledger_to_product_id_fkey(id, name)
//         ''')
//         .order('created_at', ascending: false)
//         .limit(limit);
//     return response;
//   }
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class ConvertProductPage extends StatefulWidget {
  const ConvertProductPage({super.key});

  @override
  State<ConvertProductPage> createState() => _ConvertProductPageState();
}

class _ConvertProductPageState extends State<ConvertProductPage> {
  // ── Data ─────────────────────────────────────────────────
  List _products = [];
  List _ledger = [];
  bool _loading = true;
  bool _submitting = false;

  // ── Selections ────────────────────────────────────────────
  Map<String, dynamic>? _fromProduct;
  Map<String, dynamic>? _toProduct;

  final TextEditingController _qtyFromCtrl = TextEditingController();
  final TextEditingController _qtyToCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  /// Selama user belum mengedit qty in manual, otomatis mengikuti
  /// qty out (kasus tanpa penyusutan jadi cepat diinput).
  bool _qtyToEdited = false;

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _qtyFromCtrl.dispose();
    _qtyToCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      SupabaseService.getProductsForProductConversion(),
      SupabaseService.getProductConversionLedger(limit: 10),
    ]);
    if (!mounted) return;
    setState(() {
      _products = results[0];
      _ledger = results[1];
      _loading = false;
    });
  }

  Future<void> _refreshAfterConvert() async {
    final fromId = _fromProduct?['id'] as int?;
    final toId = _toProduct?['id'] as int?;

    final results = await Future.wait([
      SupabaseService.getProductsForProductConversion(),
      SupabaseService.getProductConversionLedger(limit: 10),
    ]);

    if (!mounted) return;
    setState(() {
      _products = results[0];
      _ledger = results[1];

      // re-attach selection dari data terbaru
      Map<String, dynamic>? find(int? id) {
        if (id == null) return null;
        final list = (_products)
            .cast<Map<String, dynamic>>()
            .where((p) => p['id'] == id)
            .toList();
        return list.isNotEmpty ? list.first : null;
      }

      _fromProduct = find(fromId);
      _toProduct = find(toId);
    });
  }

  // ── Computed ──────────────────────────────────────────────
  double _num(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

  List<Map<String, dynamic>> _variantsOf(Map<String, dynamic>? product) {
    if (product == null) return [];
    final v = product['product_variants'];
    if (v == null) return [];
    return List<Map<String, dynamic>>.from(v as List);
  }

  Map<String, dynamic>? _defaultOf(Map<String, dynamic>? product) {
    final list =
        _variantsOf(product).where((v) => v['name'] == 'default').toList();
    return list.isNotEmpty ? list.first : null;
  }

  double get _qtyFrom => double.tryParse(_qtyFromCtrl.text) ?? 0;
  double get _qtyTo => double.tryParse(_qtyToCtrl.text) ?? 0;

  double get _fromStock => _num(_defaultOf(_fromProduct)?['stock']);
  double get _fromBuy => _num(_defaultOf(_fromProduct)?['buy_price']);
  double get _toStock => _num(_defaultOf(_toProduct)?['stock']);

  /// Nilai rupiah yang pindah dari A.
  double get _totalValue => _qtyFrom * _fromBuy;

  /// Estimasi avg cost baru product B (rumus sama dengan RPC).
  double? get _estNewAvg {
    if (_toProduct == null || _qtyTo <= 0) return null;
    double asset = 0, baseKg = 0;
    for (final v in _variantsOf(_toProduct)) {
      asset += _num(v['stock']) * _num(v['buy_price']);
      baseKg += _num(v['stock']) *
          (double.tryParse(v['conversion_factor']?.toString() ?? '1') ?? 1);
    }
    asset += _totalValue;
    baseKg += _qtyTo;
    if (baseKg > 0 && asset >= 0) return asset / baseKg;
    return _totalValue / _qtyTo;
  }

  /// Yield penyusutan dalam persen (3 dari 5 kg = 60%).
  double? get _yieldPct =>
      (_qtyFrom > 0 && _qtyTo > 0) ? (_qtyTo / _qtyFrom * 100) : null;

  String? get _localError {
    if (_fromProduct == null || _toProduct == null) return null;
    if (_fromProduct!['id'] == _toProduct!['id']) {
      return 'Product sumber dan tujuan harus berbeda';
    }
    if (_defaultOf(_fromProduct) == null) {
      return 'Product sumber tidak punya variant "default"';
    }
    if (_defaultOf(_toProduct) == null) {
      return 'Product tujuan tidak punya variant "default"';
    }
    if (_qtyFrom <= 0) return null; // belum diisi, jangan merah dulu
    if (_fromStock < _qtyFrom) {
      return 'Stock sumber kurang: butuh ${_fmtQty(_qtyFrom)}, '
          'tersedia ${_fmtQty(_fromStock)}';
    }
    return null;
  }

  bool get _canSubmit =>
      _fromProduct != null &&
      _toProduct != null &&
      _qtyFrom > 0 &&
      _qtyTo > 0 &&
      _localError == null &&
      !_submitting;

  // ── Helpers ───────────────────────────────────────────────
  String _fmtQty(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);

  String _fmtPrice(double price) {
    final str = price.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
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
  void _selectProductSheet({required bool isFrom}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConversionProductPickerSheet(
        products: _products,
        // excludeId: isFrom ? _toProduct?['id'] : _fromProduct?['id'],
        excludeId: isFrom ? (_toProduct?['id']) : (_fromProduct?['id']),

        title: isFrom ? 'Select Source Product' : 'Select Target Product',
        onSelect: (p) => setState(() {
          if (isFrom) {
            _fromProduct = p;
          } else {
            _toProduct = p;
          }
        }),
      ),
    );
  }

  void _onQtyFromChanged(String v) {
    setState(() {
      // Mirror ke qty in selama user belum mengedit manual
      if (!_qtyToEdited) _qtyToCtrl.text = v;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _submitting = true);
    try {
      final result = await SupabaseService.convertProduct(
        fromProductId: _fromProduct!['id'] as int,
        toProductId: _toProduct!['id'] as int,
        qtyFrom: _qtyFrom,
        qtyTo: _qtyTo,
        note: _noteCtrl.text,
      );

      await _refreshAfterConvert();

      if (mounted) {
        _snack(
          'Converted ${_fmtQty(_qtyFrom)} kg → ${_fmtQty(_qtyTo)} kg ✓  '
          '(avg cost baru: Rp ${_fmtPrice(_num(result['new_avg_cost']))})',
          success: true,
        );
        _noteCtrl.clear();
        setState(() {
          _qtyFromCtrl.clear();
          _qtyToCtrl.clear();
          _qtyToEdited = false;
        });
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
                          _buildProductPicker(
                            label: 'FROM PRODUCT (source)',
                            product: _fromProduct,
                            isFrom: true,
                          ),
                          const SizedBox(height: 20),
                          _buildProductPicker(
                            label: 'TO PRODUCT (target)',
                            product: _toProduct,
                            isFrom: false,
                          ),
                          if (_fromProduct != null &&
                              _toProduct != null) ...[
                            const SizedBox(height: 20),
                            _buildQtySection(),
                            const SizedBox(height: 20),
                            _buildPreviewCard(),
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
          (_loading || _fromProduct == null || _toProduct == null)
              ? null
              : _buildSubmitButton(),
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
                  "Product Converter",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "Convert stock between products (with cost)",
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

  // ── Product picker card ───────────────────────────────────
  Widget _buildProductPicker({
    required String label,
    required Map<String, dynamic>? product,
    required bool isFrom,
  }) {
    final def = _defaultOf(product);
    final accent =
        isFrom ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        GestureDetector(
          onTap: () => _selectProductSheet(isFrom: isFrom),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: product != null
                    ? accent.withOpacity(0.4)
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
                    color: isFrom
                        ? const Color(0xFF2D1F0A)
                        : const Color(0xFF062318),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isFrom
                        ? Icons.output_rounded
                        : Icons.input_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: product == null
                      ? const Text(
                          'Select product...',
                          style: TextStyle(
                              color: Color(0xFF4A5568), fontSize: 14),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? '-',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              def == null
                                  ? 'No "default" variant'
                                  : 'Stock ${_fmtQty(_num(def['stock']))} '
                                      '${def['unit'] ?? 'kg'}  ·  '
                                      'Buy Rp ${_fmtPrice(_num(def['buy_price']))}',
                              style: TextStyle(
                                color: def == null
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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

  // ── Quantity in/out ───────────────────────────────────────
  Widget _buildQtySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('QUANTITY (kg)'),
        Row(
          children: [
            Expanded(
              child: _qtyField(
                label: 'Out (dari sumber)',
                controller: _qtyFromCtrl,
                accent: const Color(0xFFF59E0B),
                onChanged: _onQtyFromChanged,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_forward_rounded,
                  color: Color(0xFF6C63FF), size: 20),
            ),
            Expanded(
              child: _qtyField(
                label: 'In (jadi di tujuan)',
                controller: _qtyToCtrl,
                accent: const Color(0xFF10B981),
                onChanged: (_) => setState(() => _qtyToEdited = true),
              ),
            ),
          ],
        ),
        if (_yieldPct != null && _qtyTo != _qtyFrom)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Yield ${_yieldPct!.toStringAsFixed(1)}% — '
              'susut ${_fmtQty(_qtyFrom - _qtyTo)} kg, '
              'biayanya terserap ke hasil jadi',
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _qtyField({
    required String label,
    required TextEditingController controller,
    required Color accent,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF222840), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: accent.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              hintText: '0',
              hintStyle:
                  TextStyle(color: Color(0xFF2A3040), fontSize: 18),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
            ),
            onChanged: (v) {
              onChanged(v);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  // ── Preview ───────────────────────────────────────────────
  Widget _buildPreviewCard() {
    final error = _localError;
    final avg = _estNewAvg;
    final hasQty = _qtyFrom > 0 && _qtyTo > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error != null
              ? const Color(0xFFEF4444).withOpacity(0.5)
              : const Color(0xFF222840),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewRow(
            _fromProduct?['name'] ?? 'Source',
            _fromStock,
            _fromStock - _qtyFrom,
          ),
          const SizedBox(height: 8),
          _previewRow(
            _toProduct?['name'] ?? 'Target',
            _toStock,
            _toStock + _qtyTo,
          ),
          if (hasQty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Color(0xFF222840), height: 1),
            ),
            _valueRow(
              'Nilai yang pindah',
              'Rp ${_fmtPrice(_totalValue)}',
              const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 6),
            _valueRow(
              'Est. avg cost baru (${_toProduct?['name'] ?? '-'})',
              avg == null ? '-' : 'Rp ${_fmtPrice(avg)} /kg',
              const Color(0xFF6C63FF),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewRow(String label, double before, double after) {
    final decreasing = after < before;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
        Row(
          children: [
            Text(
              '${_fmtQty(before)} kg',
              style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward_rounded,
                  color: Color(0xFF2A3040), size: 14),
            ),
            Text(
              '${_fmtQty(after)} kg',
              style: TextStyle(
                color: decreasing
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _valueRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ],
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
              hintText: 'e.g. fillet batch pagi...',
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
        _sectionLabel('RECENT CONVERSIONS'),
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
                'No product conversions yet',
                style: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
              ),
            ),
          )
        else
          ..._ledger.map((l) {
            final entry = l as Map<String, dynamic>;
            final fromName = entry['from_product']?['name'] ?? '-';
            final toName = entry['to_product']?['name'] ?? '-';
            final qtyFrom = _num(entry['qty_from']);
            final qtyTo = _num(entry['qty_to']);
            final totalValue = _num(entry['total_value']);

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
                      color: const Color(0xFF1C1030),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.sync_alt_rounded,
                        color: Color(0xFF8B5CF6), size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$fromName → $toName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _fmtDate(entry['created_at']?.toString()),
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
                        '${_fmtQty(qtyFrom)} → ${_fmtQty(qtyTo)} kg',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Rp ${_fmtPrice(totalValue)}',
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
                    'Convert Product',
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
// Product Picker Sheet — menampilkan stock & buy price default,
// men-disable product tanpa default & product yang sudah dipilih
// di sisi lain.
// ═══════════════════════════════════════════════════════════════════
class _ConversionProductPickerSheet extends StatefulWidget {
  final List products;
  final int? excludeId;
  final String title;
  final void Function(Map<String, dynamic>) onSelect;

  const _ConversionProductPickerSheet({
    required this.products,
    required this.onSelect,
    required this.title,
    this.excludeId,
  });

  @override
  State<_ConversionProductPickerSheet> createState() =>
      _ConversionProductPickerSheetState();
}

class _ConversionProductPickerSheetState
    extends State<_ConversionProductPickerSheet> {
  String _search = '';

  List get _filtered => _search.isEmpty
      ? widget.products
      : widget.products
          .where((p) => p['name']
              .toString()
              .toLowerCase()
              .contains(_search.toLowerCase()))
          .toList();

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

  String _fmtQty(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);

  String _fmtPrice(double price) {
    final str = price.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  Map<String, dynamic>? _defaultOf(Map<String, dynamic> p) {
    final variants = p['product_variants'];
    if (variants == null) return null;
    final list = List<Map<String, dynamic>>.from(variants as List)
        .where((v) => v['name'] == 'default')
        .toList();
    return list.isNotEmpty ? list.first : null;
  }

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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: const TextStyle(
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
                  final def = _defaultOf(p);
                  final excluded = p['id'] == widget.excludeId;
                  final selectable = def != null && !excluded;

                  return GestureDetector(
                    onTap: selectable
                        ? () {
                            widget.onSelect(p);
                            Navigator.pop(context);
                          }
                        : null,
                    child: Opacity(
                      opacity: selectable ? 1 : 0.4,
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
                                    excluded
                                        ? 'already selected'
                                        : def == null
                                            ? 'no default variant'
                                            : 'Buy Rp ${_fmtPrice(_num(def['buy_price']))} /${def['unit'] ?? 'kg'}',
                                    style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (def != null)
                              Text(
                                '${_fmtQty(_num(def['stock']))} '
                                '${def['unit'] ?? 'kg'}',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFF2A3040), size: 20),
                          ],
                        ),
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