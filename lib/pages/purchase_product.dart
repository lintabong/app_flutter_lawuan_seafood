import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class ProductPurchasePage extends StatefulWidget {
  @override
  State<ProductPurchasePage> createState() => _ProductPurchasePageState();
}

class _ProductPurchasePageState extends State<ProductPurchasePage> {
  // ── Data ──────────────────────────────────────────────────
  List _products = [];
  List _suppliers = [];
  bool _loading = true;

  // ── Selections ────────────────────────────────────────────
  Map<String, dynamic>? _selectedSupplier;
  String _status = 'draft';
  DateTime _purchaseDate = DateTime.now();
  final TextEditingController _descController = TextEditingController();

  /// Each entry: { 'product': Map, 'qty': double, 'price': double }
  final List<Map<String, dynamic>> _purchaseItems = [];

  bool _submitting = false;

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      SupabaseService.getProducts(),
      SupabaseService.getSuppliers(),
    ]);
    setState(() {
      _products = results[0];
      _suppliers = results[1];
      _loading = false;
    });
  }

  // ── Computed ──────────────────────────────────────────────
  double get _total => _purchaseItems.fold(
      0,
      (sum, item) =>
          sum +
          (item['qty'] as double) *
              (double.tryParse(item['price']?.toString() ?? '0') ?? 0));

  // ── Helpers ───────────────────────────────────────────────
  String _formatPrice(double price) {
    final str = price.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _formatDate(DateTime dt) {
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)}';
  }

  String _formatUtcLabel(DateTime dt) {
    final utc = dt.toUtc();
    final pad = (int n) => n.toString().padLeft(2, '0');
    return 'UTC ${utc.year}-${pad(utc.month)}-${pad(utc.day)} '
        '${pad(utc.hour)}:${pad(utc.minute)}';
  }

  List<Map<String, dynamic>> _buildItems() {
    return _purchaseItems
        .map((item) => {
              'product_id': (item['product'] as Map<String, dynamic>)['id'],
              'quantity': item['qty'] as double,
              'price': double.tryParse(item['price']?.toString() ?? '0') ?? 0,
            })
        .toList();
  }

  // ── Date picker ───────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => _pickerTheme(child),
    );
    if (picked == null) return;
    setState(() {
      _purchaseDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _purchaseDate.hour,
        _purchaseDate.minute,
      );
    });
  }

  Widget _pickerTheme(Widget? child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6C63FF),
            onPrimary: Colors.white,
            surface: Color(0xFF1E2333),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF161B27),
          textButtonTheme: TextButtonThemeData(
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFF6C63FF)),
          ),
        ),
        child: child!,
      );

  // ── Actions ───────────────────────────────────────────────
  void _openSupplierSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierPickerSheet(
        suppliers: _suppliers,
        selectedId: _selectedSupplier?['id'],
        onSelect: (s) => setState(() => _selectedSupplier = s),
      ),
    );
  }

  void _openProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductPickerSheet(
        products: _products,
        addedIds: _purchaseItems
            .map((i) => (i['product'] as Map<String, dynamic>)['id'])
            .toList(),
        onAdd: (product, qty, price) {
          setState(() {
            final idx = _purchaseItems.indexWhere(
                (i) => (i['product'] as Map)['id'] == product['id']);
            if (idx >= 0) {
              _purchaseItems[idx]['qty'] =
                  (_purchaseItems[idx]['qty'] as double) + qty;
            } else {
              _purchaseItems
                  .add({'product': product, 'qty': qty, 'price': price});
            }
          });
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedSupplier == null) {
      _snack('Please select a supplier');
      return;
    }
    if (_purchaseItems.isEmpty) {
      _snack('Add at least one product');
      return;
    }
    for (final item in _purchaseItems) {
      if ((item['qty'] as double) <= 0) {
        _snack('Quantity must be > 0 for all items');
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final result = await SupabaseService.productPurchaseTransaction(
        supplierId: _selectedSupplier!['id'] as int,
        status: _status,
        description: _descController.text.trim(),
        transactionDate: _purchaseDate,
        items: _buildItems(),
      );

      if (mounted) {
        _snack('Purchase #${result['transaction_id']} saved ✓', success: true);
        Navigator.pop(context, result);
      }
    } catch (e) {
      _snack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                          _buildDateSection(),
                          const SizedBox(height: 20),
                          _buildSupplierSection(),
                          const SizedBox(height: 20),
                          _buildStatusSection(),
                          const SizedBox(height: 20),
                          _buildDescriptionSection(),
                          const SizedBox(height: 20),
                          _buildItemsSection(),
                          const SizedBox(height: 20),
                          if (_purchaseItems.isNotEmpty) _buildSummaryCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: _loading ? null : _buildSubmitButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ── Header ─────────────────────────────────────────────────
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
                  "Product Purchase",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "New purchase transaction",
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────
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

  // ── Date ───────────────────────────────────────────────────
  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PURCHASE DATE'),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF222840), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2744),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today_rounded,
                      color: Color(0xFF60A5FA), size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(_purchaseDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _formatUtcLabel(_purchaseDate),
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_calendar_rounded,
                    color: Color(0xFF2A3040), size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Supplier ───────────────────────────────────────────────
  Widget _buildSupplierSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SUPPLIER'),
        GestureDetector(
          onTap: _openSupplierSheet,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedSupplier != null
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
                  child: const Icon(Icons.storefront_rounded,
                      color: Color(0xFF6C63FF), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedSupplier == null
                      ? const Text(
                          'Select supplier...',
                          style: TextStyle(
                              color: Color(0xFF4A5568), fontSize: 14),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedSupplier!['name'] ?? '-',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if ((_selectedSupplier!['phone'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Text(
                                _selectedSupplier!['phone'],
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 12),
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

  // ── Status ─────────────────────────────────────────────────
  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('STATUS'),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF222840), width: 1),
          ),
          child: Row(
            children: [
              _statusToggle('draft', Icons.edit_note_rounded, 'Draft',
                  const Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              _statusToggle('posted', Icons.check_circle_outline_rounded,
                  'Posted', const Color(0xFF10B981)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusToggle(
      String value, IconData icon, String label, Color color) {
    final active = _status == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? color.withOpacity(0.45) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: active ? color : const Color(0xFF4A5568)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? color : const Color(0xFF4A5568),
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Description ────────────────────────────────────────────
  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('DESCRIPTION'),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF222840), width: 1),
          ),
          child: TextField(
            controller: _descController,
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Optional notes about this purchase...',
              hintStyle:
                  TextStyle(color: Color(0xFF4A5568), fontSize: 13),
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.notes_rounded,
                    color: Color(0xFF4A5568), size: 20),
              ),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ── Items ──────────────────────────────────────────────────
  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionLabel('PURCHASE ITEMS')),
            GestureDetector(
              onTap: _openProductSheet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded,
                        color: Color(0xFF6C63FF), size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Add Item',
                      style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_purchaseItems.isEmpty)
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF222840), width: 1),
            ),
            child: const Center(
              child: Text(
                'No items added yet',
                style: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
              ),
            ),
          )
        else
          ...List.generate(_purchaseItems.length, (i) {
            final item = _purchaseItems[i];
            final product = item['product'] as Map<String, dynamic>;
            final qty = item['qty'] as double;
            final price =
                double.tryParse(item['price']?.toString() ?? '0') ?? 0;
            final subtotal = qty * price;

            final qtyCtrl = TextEditingController(
              text: qty % 1 == 0
                  ? qty.toInt().toString()
                  : qty.toStringAsFixed(2),
            );
            final priceCtrl = TextEditingController(
              text: price > 0 ? price.toInt().toString() : '',
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161B27),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: const Color(0xFF222840), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name row
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B4B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.inventory_2_rounded,
                            color: Color(0xFF6C63FF), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? '-',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              product['unit'] ?? '-',
                              style: const TextStyle(
                                  color: Color(0xFF64748B), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _purchaseItems.removeAt(i)),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Color(0xFFEF4444), size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Qty + Price row
                  Row(
                    children: [
                      // Qty stepper
                      Row(
                        children: [
                          _qtyBtn(Icons.remove_rounded, () {
                            setState(() {
                              if (qty <= 1) {
                                _purchaseItems.removeAt(i);
                              } else {
                                _purchaseItems[i]['qty'] = double.parse(
                                    (qty - 1).toStringAsFixed(2));
                              }
                            });
                          }),
                          SizedBox(
                            width: 52,
                            child: TextField(
                              controller: qtyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 4),
                              ),
                              onChanged: (v) {
                                final parsed = double.tryParse(v);
                                if (parsed != null && parsed > 0) {
                                  setState(() => _purchaseItems[i]['qty'] =
                                      double.parse(
                                          parsed.toStringAsFixed(2)));
                                }
                              },
                              onSubmitted: (v) {
                                final parsed = double.tryParse(v);
                                if (parsed == null || parsed <= 0) {
                                  setState(
                                      () => _purchaseItems.removeAt(i));
                                }
                              },
                            ),
                          ),
                          _qtyBtn(Icons.add_rounded, () {
                            setState(() => _purchaseItems[i]['qty'] =
                                double.parse(
                                    (qty + 1).toStringAsFixed(2)));
                          }),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Price input
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1117),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF222840), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Buy Price',
                                style: TextStyle(
                                    color: Color(0xFF4A5568),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Text('Rp ',
                                      style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13)),
                                  Expanded(
                                    child: TextField(
                                      controller: priceCtrl,
                                      keyboardType:
                                          TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter
                                            .digitsOnly
                                      ],
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13),
                                      decoration:
                                          const InputDecoration(
                                        hintText: '0',
                                        hintStyle: TextStyle(
                                            color: Color(0xFF2A3040),
                                            fontSize: 13),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding:
                                            EdgeInsets.zero,
                                      ),
                                      onChanged: (v) {
                                        setState(() =>
                                            _purchaseItems[i]['price'] =
                                                double.tryParse(v) ??
                                                    0);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Subtotal
                      if (subtotal > 0) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Rp ${_formatPrice(subtotal)}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF222840),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        ),
      );

  // ── Summary ────────────────────────────────────────────────
  Widget _buildSummaryCard() {
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
          const Text(
            'Total',
            style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
          Text(
            'Rp ${_formatPrice(_total)}',
            style: const TextStyle(
              color: Color(0xFF10B981),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit button ──────────────────────────────────────────
  Widget _buildSubmitButton() {
    final isPosted = _status == 'posted';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: _submitting ? null : _submit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPosted
                  ? [const Color(0xFF059669), const Color(0xFF10B981)]
                  : [const Color(0xFF6C63FF), const Color(0xFF4F46E5)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isPosted
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6C63FF))
                    .withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
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
                    isPosted ? 'Post Purchase' : 'Save as Draft',
                    style: const TextStyle(
                      color: Colors.white,
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

// ═══════════════════════════════════════════════════════════════════════════════
// Supplier Picker Sheet
// ═══════════════════════════════════════════════════════════════════════════════
class _SupplierPickerSheet extends StatefulWidget {
  final List suppliers;
  final int? selectedId;
  final void Function(Map<String, dynamic>) onSelect;

  const _SupplierPickerSheet({
    required this.suppliers,
    required this.onSelect,
    this.selectedId,
  });

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  String _search = '';

  List get _filtered => _search.isEmpty
      ? widget.suppliers
      : widget.suppliers
          .where((s) =>
              s['name']
                  .toString()
                  .toLowerCase()
                  .contains(_search.toLowerCase()) ||
              (s['phone'] ?? '').toString().contains(_search))
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
                  'Select Supplier',
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
                    hintText: 'Search supplier...',
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
                  final s = _filtered[i] as Map<String, dynamic>;
                  final selected = widget.selectedId == s['id'];
                  return GestureDetector(
                    onTap: () {
                      widget.onSelect(s);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF1E1B4B)
                            : const Color(0xFF0F1117),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF6C63FF).withOpacity(0.5)
                              : const Color(0xFF222840),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF6C63FF).withOpacity(0.15)
                                  : const Color(0xFF1E1B4B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.storefront_rounded,
                                color: selected
                                    ? const Color(0xFF6C63FF)
                                    : const Color(0xFF4A5568),
                                size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['name'] ?? '-',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if ((s['phone'] ?? '').toString().isNotEmpty)
                                  Text(
                                    s['phone'],
                                    style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF6C63FF), size: 20)
                          else
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

// ═══════════════════════════════════════════════════════════════════════════════
// Product Picker Sheet
// ═══════════════════════════════════════════════════════════════════════════════
class _ProductPickerSheet extends StatefulWidget {
  final List products;
  final List addedIds;
  final void Function(Map<String, dynamic> product, double qty, double price)
      onAdd;

  const _ProductPickerSheet({
    required this.products,
    required this.addedIds,
    required this.onAdd,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _search = '';
  Map<String, dynamic>? _selectedProduct;
  double _qty = 1.0;
  double _price = 0;

  final TextEditingController _searchCtrl = TextEditingController();
  late final TextEditingController _qtyCtrl =
      TextEditingController(text: '1');
  late final TextEditingController _priceCtrl =
      TextEditingController(text: '');

  List get _filtered => _search.isEmpty
      ? widget.products
      : widget.products
          .where((p) => p['name']
              .toString()
              .toLowerCase()
              .contains(_search.toLowerCase()))
          .toList();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  String _formatPrice(double price) {
    final str = price.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
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
            // Handle
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
                  if (_selectedProduct != null)
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedProduct = null;
                        _search = '';
                        _searchCtrl.clear();
                      }),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(Icons.arrow_back_rounded,
                            color: Color(0xFF6C63FF), size: 20),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _selectedProduct == null
                          ? 'Add Product'
                          : _selectedProduct!['name'] ?? '-',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_selectedProduct != null && _qty > 0)
                    GestureDetector(
                      onTap: () {
                        widget.onAdd(_selectedProduct!, _qty, _price);
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
                          'Add ×${_qty % 1 == 0 ? _qty.toInt() : _qty.toStringAsFixed(2)}',
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

            // Search bar (product list only)
            if (_selectedProduct == null)
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
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(
                          color: Color(0xFF4A5568), fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: Color(0xFF4A5568), size: 18),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: _selectedProduct == null
                  ? _buildProductList(scrollCtrl)
                  : _buildDetailPicker(scrollCtrl),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList(ScrollController ctrl) {
    return ListView.builder(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final p = _filtered[i] as Map<String, dynamic>;
        final alreadyAdded = widget.addedIds.contains(p['id']);
        return GestureDetector(
          onTap: alreadyAdded
              ? null
              : () {
                  setState(() {
                    _selectedProduct = p;
                    _qty = 1.0;
                    _price =
                        double.tryParse(p['buy_price']?.toString() ?? '0') ??
                            0;
                    if (_price > 0) {
                      _priceCtrl.text = _price.toInt().toString();
                    } else {
                      _priceCtrl.clear();
                    }
                    _qtyCtrl.text = '1';
                  });
                },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: alreadyAdded
                  ? const Color(0xFF0F1117).withOpacity(0.5)
                  : const Color(0xFF0F1117),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF222840)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: alreadyAdded
                        ? const Color(0xFF1A1F2E)
                        : const Color(0xFF1E1B4B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2_rounded,
                      color: alreadyAdded
                          ? const Color(0xFF2A3040)
                          : const Color(0xFF6C63FF),
                      size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['name'] ?? '-',
                        style: TextStyle(
                          color: alreadyAdded
                              ? const Color(0xFF4A5568)
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        p['unit'] ?? '-',
                        style: const TextStyle(
                            color: Color(0xFF4A5568), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (alreadyAdded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Added',
                        style: TextStyle(
                            color: Color(0xFF6C63FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  )
                else
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF2A3040), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailPicker(ScrollController ctrl) {
    final subtotal = _qty * _price;
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        // Qty
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
                final n = _qty - 1 < 1 ? 1.0 : _qty - 1;
                _qty = double.parse(n.toStringAsFixed(2));
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
                _qty = double.parse((_qty + 1).toStringAsFixed(2));
                _qtyCtrl.text = _qty % 1 == 0
                    ? _qty.toInt().toString()
                    : _qty.toStringAsFixed(2);
              });
            }),
          ],
        ),
        const SizedBox(height: 20),

        // Buy price
        const Text(
          'BUY PRICE',
          style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1117),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF222840)),
          ),
          child: Row(
            children: [
              const Text('Rp ',
                  style: TextStyle(
                      color: Color(0xFF64748B), fontSize: 14)),
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                        color: Color(0xFF2A3040), fontSize: 16),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    setState(() => _price = double.tryParse(v) ?? 0);
                  },
                ),
              ),
            ],
          ),
        ),

        // Subtotal preview
        if (subtotal > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal',
                    style: TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 13)),
                Text(
                  'Rp ${_formatPrice(subtotal)}',
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
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