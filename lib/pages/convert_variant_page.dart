
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

/// Halaman Variant Converter (repack).
///
/// Alur:
///   1. Pilih product (bottom sheet + search, sama seperti order page)
///   2. Pilih arah: Pack (default → variant) atau Unpack (variant → default)
///   3. Pilih target variant non-default (kartu radio, tampil factor & stock)
///   4. Atur quantity → preview real-time berapa kg yang berpindah
///   5. Submit → RPC convert_product_variant → stock di-refresh
class ConvertVariantPage extends StatefulWidget {
  const ConvertVariantPage({super.key});

  @override
  State<ConvertVariantPage> createState() => _ConvertVariantPageState();
}

class _ConvertVariantPageState extends State<ConvertVariantPage> {
  // ── Data ─────────────────────────────────────────────────
  List _products = [];
  List _ledger = [];
  bool _loading = true;
  bool _submitting = false;

  // ── Selections ────────────────────────────────────────────
  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _selectedVariant; // target non-default
  String _direction = 'pack'; // 'pack' | 'unpack'
  double _qty = 1.0;

  late final TextEditingController _qtyCtrl =
      TextEditingController(text: '1');
  final TextEditingController _noteCtrl = TextEditingController();

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final products = await SupabaseService.getProductsForConversion();
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  Future<void> _refreshAfterConvert() async {
    final productId = _selectedProduct?['id'] as int?;
    final results = await Future.wait([
      SupabaseService.getProductsForConversion(),
      if (productId != null)
        SupabaseService.getConversionLedger(productId: productId, limit: 10),
    ]);

    setState(() {
      _products = results[0];

      // re-attach selected product & variant dari data terbaru
      if (productId != null) {
        final fresh = (_products).cast<Map<String, dynamic>>()
            .where((p) => p['id'] == productId)
            .toList();
        if (fresh.isNotEmpty) {
          _selectedProduct = fresh.first;
          final vid = _selectedVariant?['id'];
          if (vid != null) {
            final vs = _variantsOf(_selectedProduct!)
                .where((v) => v['id'] == vid)
                .toList();
            _selectedVariant = vs.isNotEmpty ? vs.first : null;
          }
        }
        if (results.length > 1) _ledger = results[1];
      }
    });
  }

  Future<void> _loadLedger(int productId) async {
    final ledger = await SupabaseService.getConversionLedger(
      productId: productId,
      limit: 10,
    );
    if (mounted) setState(() => _ledger = ledger);
  }

  // ── Computed ──────────────────────────────────────────────
  List<Map<String, dynamic>> _variantsOf(Map<String, dynamic> product) {
    final v = product['product_variants'];
    if (v == null) return [];
    return List<Map<String, dynamic>>.from(v as List);
  }

  Map<String, dynamic>? get _defaultVariant {
    if (_selectedProduct == null) return null;
    final list = _variantsOf(_selectedProduct!)
        .where((v) => v['name'] == 'default')
        .toList();
    return list.isNotEmpty ? list.first : null;
  }

  List<Map<String, dynamic>> get _targetVariants {
    if (_selectedProduct == null) return [];
    return _variantsOf(_selectedProduct!)
        .where((v) => v['name'] != 'default' && (v['is_active'] ?? true) == true)
        .toList();
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

  double get _factor => _num(_selectedVariant?['conversion_factor']);
  double get _baseQty =>
      double.parse((_qty * _factor).toStringAsFixed(2));
  double get _defaultStock => _num(_defaultVariant?['stock']);
  double get _variantStock => _num(_selectedVariant?['stock']);

  /// Validasi lokal (server tetap validasi ulang dengan lock).
  String? get _localError {
    if (_selectedVariant == null) return null;
    if (_factor <= 0) {
      return 'Variant ini belum punya conversion factor yang valid';
    }
    if (_direction == 'pack' && _defaultStock < _baseQty) {
      return 'Stock default kurang: butuh ${_fmtQty(_baseQty)}, '
          'tersedia ${_fmtQty(_defaultStock)}';
    }
    if (_direction == 'unpack' && _variantStock < _qty) {
      return 'Stock variant kurang: butuh ${_fmtQty(_qty)}, '
          'tersedia ${_fmtQty(_variantStock)}';
    }
    return null;
  }

  bool get _canSubmit =>
      _selectedProduct != null &&
      _selectedVariant != null &&
      _defaultVariant != null &&
      _qty > 0 &&
      _localError == null &&
      !_submitting;

  // ── Helpers ───────────────────────────────────────────────
  String _fmtQty(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);

  String _fmtFactor(double f) {
    var s = f.toStringAsFixed(4);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s;
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

  void _setQty(double q) {
    _qty = double.parse(q.toStringAsFixed(2));
    _qtyCtrl.text = _fmtQty(_qty);
  }

  // ── Actions ───────────────────────────────────────────────
  void _selectProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConverterProductPickerSheet(
        products: _products,
        onSelect: (p) {
          setState(() {
            _selectedProduct = p;
            _selectedVariant = null;
            _ledger = [];
            _setQty(1);
          });
          _loadLedger(p['id'] as int);
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _submitting = true);
    try {
      final result = await SupabaseService.convertProductVariant(
        productId: _selectedProduct!['id'] as int,
        variantId: _selectedVariant!['id'] as int,
        quantity: _qty,
        direction: _direction,
        note: _noteCtrl.text,
      );

      await _refreshAfterConvert();

      if (mounted) {
        final vName = _selectedVariant?['name'] ?? 'variant';
        final msg = _direction == 'pack'
            ? 'Packed ${_fmtQty(_qty)} × $vName ✓  '
                '(default: ${_fmtQty(_num(result['default_stock']))})'
            : 'Unpacked ${_fmtQty(_qty)} × $vName ✓  '
                '(default: ${_fmtQty(_num(result['default_stock']))})';
        _snack(msg, success: true);
        _noteCtrl.clear();
        setState(() => _setQty(1));
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
                            _buildDirectionSection(),
                            const SizedBox(height: 20),
                            _buildVariantSection(),
                            if (_selectedVariant != null) ...[
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton:
          (_loading || _selectedVariant == null) ? null : _buildSubmitButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
                  "Variant Converter",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "Repack stock between default & variants",
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
    final def = _defaultVariant;
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
                  child: const Icon(Icons.inventory_2_rounded,
                      color: Color(0xFF6C63FF), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedProduct == null
                      ? const Text(
                          'Select product...',
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
                              def == null
                                  ? 'No "default" variant — cannot convert'
                                  : 'Default stock: ${_fmtQty(_num(def['stock']))} '
                                      '${def['unit'] ?? _selectedProduct!['unit'] ?? ''}',
                              style: TextStyle(
                                color: def == null
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
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

  // ── Direction ─────────────────────────────────────────────
  Widget _buildDirectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('DIRECTION'),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF222840), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                _directionToggle(
                  'pack',
                  Icons.call_split_rounded,
                  'Pack',
                  'default → variant',
                ),
                const SizedBox(width: 6),
                _directionToggle(
                  'unpack',
                  Icons.merge_rounded,
                  'Unpack',
                  'variant → default',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _directionToggle(
      String value, IconData icon, String label, String sub) {
    final active = _direction == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _direction = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1E1B4B) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? const Color(0xFF6C63FF).withOpacity(0.5)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 16,
                      color: active
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFF4A5568)),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFF4A5568),
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  color: active
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF2A3040),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Variant ───────────────────────────────────────────────
  Widget _buildVariantSection() {
    final variants = _targetVariants;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('TARGET VARIANT'),
        if (variants.isEmpty)
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF222840), width: 1),
            ),
            child: const Center(
              child: Text(
                'This product has no non-default variants',
                style: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
              ),
            ),
          )
        else
          ...variants.map((v) {
            final selected = _selectedVariant?['id'] == v['id'];
            final factor = _num(v['conversion_factor']);
            final stock = _num(v['stock']);
            final unit =
                _defaultVariant?['unit'] ?? _selectedProduct?['unit'] ?? 'kg';

            return GestureDetector(
              onTap: () => setState(() => _selectedVariant = v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1E1B4B)
                      : const Color(0xFF161B27),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF6C63FF).withOpacity(0.6)
                        : const Color(0xFF222840),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFF2A3040),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v['name'] ?? '-',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '1 × = ${_fmtFactor(factor)} $unit',
                            style: const TextStyle(
                                color: Color(0xFF64748B), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'stock ${_fmtQty(stock)}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ── Quantity ──────────────────────────────────────────────
  Widget _buildQtySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('QUANTITY (${_selectedVariant?['name'] ?? 'variant'})'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF222840), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _qtyBtn(Icons.remove_rounded, () {
                setState(() => _setQty(_qty - 1 < 1 ? 1 : _qty - 1));
              }),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null && parsed > 0) {
                      setState(() =>
                          _qty = double.parse(parsed.toStringAsFixed(2)));
                    }
                  },
                ),
              ),
              _qtyBtn(Icons.add_rounded, () {
                setState(() => _setQty(_qty + 1));
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF222840),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        ),
      );

  // ── Preview ───────────────────────────────────────────────
  Widget _buildPreviewCard() {
    final unit =
        _defaultVariant?['unit'] ?? _selectedProduct?['unit'] ?? 'kg';
    final vName = _selectedVariant?['name'] ?? '-';
    final error = _localError;

    final isPack = _direction == 'pack';
    final newDefault =
        isPack ? _defaultStock - _baseQty : _defaultStock + _baseQty;
    final newVariant = isPack ? _variantStock + _qty : _variantStock - _qty;

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
          // Rumus konversi
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_fmtQty(_qty)} × $vName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  isPack
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                  color: const Color(0xFF6C63FF),
                  size: 18,
                ),
              ),
              Text(
                '${_fmtQty(_baseQty)} $unit default',
                style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFF222840), height: 1),
          ),
          _previewRow(
            'default',
            _defaultStock,
            newDefault,
            unit.toString(),
          ),
          const SizedBox(height: 8),
          _previewRow(
            vName.toString(),
            _variantStock,
            newVariant,
            'pcs',
          ),
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

  Widget _previewRow(String label, double before, double after, String unit) {
    final decreasing = after < before;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Row(
          children: [
            Text(
              '${_fmtQty(before)} $unit',
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
              '${_fmtQty(after)} $unit',
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
              hintText: 'e.g. repack for weekend market...',
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
                'No conversions yet for this product',
                style: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
              ),
            ),
          )
        else
          ..._ledger.map((l) {
            final entry = l as Map<String, dynamic>;
            final fromName = entry['from_variant']?['name'] ?? '-';
            final toName = entry['to_variant']?['name'] ?? '-';
            final qty = _num(entry['quantity']);
            final baseQty = _num(entry['base_qty']);
            final unit = entry['products']?['unit'] ?? 'kg';
            final isPack = fromName == 'default';

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
                      color: isPack
                          ? const Color(0xFF1E1B4B)
                          : const Color(0xFF16281F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPack
                          ? Icons.call_split_rounded
                          : Icons.merge_rounded,
                      color: isPack
                          ? const Color(0xFF6C63FF)
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
                          '$fromName → $toName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
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
                        '${_fmtQty(qty)} pcs',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_fmtQty(baseQty)} $unit',
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
                    _direction == 'pack' ? 'Pack Variant' : 'Unpack Variant',
                    style: TextStyle(
                      color: enabled
                          ? Colors.white
                          : const Color(0xFF4A5568),
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
// Product Picker Sheet (khusus converter — menampilkan default stock)
// ═══════════════════════════════════════════════════════════════════
class _ConverterProductPickerSheet extends StatefulWidget {
  final List products;
  final void Function(Map<String, dynamic>) onSelect;

  const _ConverterProductPickerSheet({
    required this.products,
    required this.onSelect,
  });

  @override
  State<_ConverterProductPickerSheet> createState() =>
      _ConverterProductPickerSheetState();
}

class _ConverterProductPickerSheetState
    extends State<_ConverterProductPickerSheet> {
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

  Map<String, dynamic>? _defaultOf(Map<String, dynamic> p) {
    final variants = p['product_variants'];
    if (variants == null) return null;
    final list = List<Map<String, dynamic>>.from(variants as List)
        .where((v) => v['name'] == 'default')
        .toList();
    return list.isNotEmpty ? list.first : null;
  }

  int _variantCountOf(Map<String, dynamic> p) {
    final variants = p['product_variants'];
    if (variants == null) return 0;
    return List.from(variants as List)
        .where((v) => v['name'] != 'default')
        .length;
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
                  final def = _defaultOf(p);
                  final variantCount = _variantCountOf(p);
                  final hasDefault = def != null;

                  return GestureDetector(
                    onTap: hasDefault
                        ? () {
                            widget.onSelect(p);
                            Navigator.pop(context);
                          }
                        : null,
                    child: Opacity(
                      opacity: hasDefault ? 1 : 0.4,
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
                                    hasDefault
                                        ? '$variantCount variant'
                                            '${variantCount == 1 ? '' : 's'}'
                                        : 'no default variant',
                                    style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (hasDefault)
                              Text(
                                '${_fmtQty(_num(def['stock']))} '
                                '${def['unit'] ?? p['unit'] ?? ''}',
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