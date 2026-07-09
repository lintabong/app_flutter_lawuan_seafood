
import 'package:flutter/material.dart';

String _formatPrice(double price) {
  final str = price.toInt().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
    buffer.write(str[i]);
  }
  return buffer.toString();
}

String _formatStock(double v) =>
    v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

class ProductPickerSheet extends StatefulWidget {
  final List products;
  final void Function(
      Map<String, dynamic> product,
      Map<String, dynamic> variant,
      double qty) onAdd;

  const ProductPickerSheet(
      {super.key, required this.products, required this.onAdd});

  @override
  State<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<ProductPickerSheet> {
  String _search = '';
  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _selectedVariant;
  double _qty = 1.0;
  final TextEditingController _searchCtrl = TextEditingController();
  late final TextEditingController _qtyCtrl =
      TextEditingController(text: '1');

  List get _filtered => _search.isEmpty
      ? widget.products
      : widget.products
          .where((p) => p['name']
              .toString()
              .toLowerCase()
              .contains(_search.toLowerCase()))
          .toList();

  List<Map<String, dynamic>> get _variants {
    if (_selectedProduct == null) return [];
    final v = _selectedProduct!['product_variants'];
    if (v == null) return [];
    return List<Map<String, dynamic>>.from(v as List);
  }

  // ── Stock helpers ──────────────────────────────────────────────────────
  double _variantStock(Map v) =>
      double.tryParse(v['stock']?.toString() ?? '0') ?? 0;

  /// Total stok produk = Σ(stock × conversion_factor) dari semua variant.
  /// Setara kg, konsisten dengan getTotalStockKg di dashboard.
  double _productStockKg(Map p) {
    final vs = p['product_variants'];
    if (vs == null) return 0;
    double total = 0;
    for (final v in (vs as List)) {
      final s = double.tryParse(v['stock']?.toString() ?? '0') ?? 0;
      final f = double.tryParse(v['conversion_factor']?.toString() ?? '1') ?? 1;
      total += s * f;
    }
    return total;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
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
              child: Row(
                children: [
                  const Text(
                    'Add Product',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedProduct != null && _selectedVariant != null)
                    GestureDetector(
                      onTap: () {
                        widget.onAdd(
                            _selectedProduct!, _selectedVariant!, _qty);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Add  ×${_qty % 1 == 0 ? _qty.toInt() : _qty.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1117),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF222840)),
                ),
                child: TextField(
                  controller: _searchCtrl,
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
              child: _selectedProduct == null
                  ? ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i] as Map<String, dynamic>;
                        final stockKg = _productStockKg(p);
                        final empty = stockKg <= 0;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedProduct = p;
                            final v = _variants;
                            _selectedVariant = v.isNotEmpty ? v[0] : null;
                          }),
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
                                  child: const Icon(
                                      Icons.inventory_2_rounded,
                                      color: Color(0xFF6C63FF),
                                      size: 18),
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
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.layers_rounded,
                                            size: 11,
                                            color: empty
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            empty
                                                ? 'Out of stock'
                                                : 'Stock ${_formatStock(stockKg)} kg',
                                            style: TextStyle(
                                              color: empty
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF64748B),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
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
                    )
                  : _buildVariantPicker(scrollCtrl),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantPicker(ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _selectedProduct = null;
            _selectedVariant = null;
          }),
          child: Row(
            children: [
              const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF6C63FF), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _selectedProduct!['name'] ?? '-',
                  style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ),
              // Total stok produk di header variant picker
              Text(
                'Total ${_formatStock(_productStockKg(_selectedProduct!))} kg',
                style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'SELECT VARIANT',
          style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        ..._variants.map((v) {
          final selected = _selectedVariant?['id'] == v['id'];
          final price =
              double.tryParse(v['sell_price']?.toString() ?? '0') ?? 0;
          final stock = _variantStock(v);
          final unit = (v['unit'] ?? '').toString();
          final empty = stock <= 0;
          return GestureDetector(
            onTap: () => setState(() => _selectedVariant = v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF1E1B4B)
                    : const Color(0xFF0F1117),
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
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 11,
                              color: empty
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              empty
                                  ? 'Out of stock'
                                  : 'Stock ${_formatStock(stock)}${unit.isNotEmpty ? ' $unit' : ''}',
                              style: TextStyle(
                                color: empty
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF64748B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Rp ${_formatPrice(price)}',
                    style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        const Text(
          'QUANTITY',
          style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _qtyBtn(Icons.remove_rounded, () {
              setState(() {
                final newQty = double.parse(
                  (_qty - 0.01 < 0.01 ? 0.01 : _qty - 0.01)
                      .toStringAsFixed(2),
                );
                _qty = newQty;
                _qtyCtrl.text = _qty % 1 == 0
                    ? _qty.toInt().toString()
                    : _qty.toStringAsFixed(2);
              });
            }),
            SizedBox(
              width: 64,
              child: TextField(
                controller: _qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
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
              setState(() {
                _qty = double.parse((_qty + 0.01).toStringAsFixed(2));
                _qtyCtrl.text = _qty % 1 == 0
                    ? _qty.toInt().toString()
                    : _qty.toStringAsFixed(2);
              });
            }),
          ],
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
            color: const Color(0xFF1E2333),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Customer Picker Sheet
// ═══════════════════════════════════════════════════════════════════════════
class CustomerPickerSheet extends StatefulWidget {
  final List customers;
  final void Function(Map<String, dynamic>) onSelect;

  const CustomerPickerSheet(
      {super.key, required this.customers, required this.onSelect});

  @override
  State<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<CustomerPickerSheet> {
  String _search = '';

  List get _filtered => _search.isEmpty
      ? widget.customers
      : widget.customers
          .where((c) =>
              c['name']
                  .toString()
                  .toLowerCase()
                  .contains(_search.toLowerCase()) ||
              (c['phone'] ?? '').toString().contains(_search))
          .toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Container(
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Customer',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
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
                    hintText: 'Search name or phone...',
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
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final c = _filtered[i] as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () {
                      widget.onSelect(c);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1117),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF222840)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                                color: const Color(0xFF1E1B4B),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.person_rounded,
                                color: Color(0xFF6C63FF), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['name'] ?? '-',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (c['phone'] != null)
                                  Text(
                                    c['phone'],
                                    style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12),
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