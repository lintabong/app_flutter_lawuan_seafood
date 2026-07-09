import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import './widgets/order_pickers.dart';

class CreateOrderPage extends StatefulWidget {
  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  // ── Data ─────────────────────────────────────────────────
  List _customers = [];
  List _products = [];
  List _cashes = [];
  bool _loading = true;

  // ── Selections ────────────────────────────────────────────
  Map<String, dynamic>? _selectedCustomer;
  Map<String, dynamic>? _selectedCash;
  String _deliveryType = 'pickup';
  double _deliveryPrice = 0;
  String _status = 'pending';

  /// Order date/time — defaults to now, user can override
  DateTime _orderDate = DateTime.now();

  final TextEditingController _deliveryPriceController =
      TextEditingController(text: '0');
  final TextEditingController _customerSearchCtrl = TextEditingController();

  /// Each entry: { product, variant, qty, sell_price }
  /// qty is stored as double to support 0.01 steps
  /// sell_price is editable per-item, seeded from variant['sell_price']
  final List<Map<String, dynamic>> _orderItems = [];

  bool _submitting = false;

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _deliveryPriceController.dispose();
    _customerSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      SupabaseService.getCustomers(),
      SupabaseService.getProducts(),
      _getCashes(),
    ]);
    setState(() {
      _customers = results[0];
      _products = results[1];
      _cashes = results[2];
      if (_cashes.isNotEmpty) _selectedCash = _cashes[0];
      _loading = false;
    });
  }

  Future<List<dynamic>> _getCashes() async {
    try {
      final response =
          await supabase.from('cash').select('id, name, balance').order('id');
      return response;
    } catch (_) {
      return [];
    }
  }

  // ── Computed ──────────────────────────────────────────────
  double get _itemsTotal => _orderItems.fold(0, (sum, item) {
        final price =
            double.tryParse(item['sell_price']?.toString() ?? '0') ?? 0;
        return sum + price * (item['qty'] as double);
      });

  double get _grandTotal => _itemsTotal + _deliveryPrice;

  double _variantSellPrice(Map<String, dynamic>? variant) {
    if (variant == null) return 0;
    return double.tryParse(variant['sell_price']?.toString() ?? '0') ?? 0;
  }

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

  String _formatOrderDate(DateTime dt) {
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)}  '
        '${pad(dt.hour)}:${pad(dt.minute)}';
  }

  String _formatUtcLabel(DateTime dt) {
    final utc = dt.toUtc();
    final pad = (int n) => n.toString().padLeft(2, '0');
    return 'UTC ${utc.year}-${pad(utc.month)}-${pad(utc.day)} '
        '${pad(utc.hour)}:${pad(utc.minute)}';
  }

  List<Map<String, dynamic>> _buildItems() {
    return _orderItems.map((item) {
      final product = item['product'] as Map<String, dynamic>;
      final variant = item['variant'] as Map<String, dynamic>;
      return {
        'product_id': product['id'],
        'variant_id': variant['id'],
        'qty': item['qty'] as double,
        'buy_price':
            double.tryParse(variant['buy_price']?.toString() ?? '0') ?? 0,
        'sell_price':
            double.tryParse(item['sell_price']?.toString() ?? '0') ?? 0,
      };
    }).toList();
  }

  // ── Date / Time picker ────────────────────────────────────
  Future<void> _pickOrderDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => _datePickerTheme(child),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_orderDate),
      builder: (context, child) => _datePickerTheme(child),
    );

    setState(() {
      _orderDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? _orderDate.hour,
        pickedTime?.minute ?? _orderDate.minute,
      );
    });
  }

  Widget _datePickerTheme(Widget? child) {
    return Theme(
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
  }

  // ── Actions ───────────────────────────────────────────────
  void _addProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductPickerSheet(
        products: _products,
        onAdd: (product, variant, qty) {
          // Always add as a NEW line — same variant can appear multiple
          // times (e.g. kakap fillet 0.4kg and 0.7kg as separate rows).
          setState(() {
            _orderItems.add({
              'product': product,
              'variant': variant,
              'qty': qty,
              // seed editable sell_price from the variant
              'sell_price': _variantSellPrice(variant),
            });
          });
        },
      ),
    );
  }

  void _selectCustomerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerPickerSheet(
        customers: _customers,
        onSelect: (c) => setState(() => _selectedCustomer = c),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedCustomer == null) {
      _snack('Please select a customer');
      return;
    }
    if (_selectedCash == null) {
      _snack('Please select a cash account');
      return;
    }
    if (_orderItems.isEmpty) {
      _snack('Add at least one product');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await SupabaseService.createOrder(
        customerId: _selectedCustomer!['id'] as int,
        status: _status,
        cashId: _selectedCash!['id'] as int,
        items: _buildItems(),
        deliveryPrice: _deliveryPrice,
        deliveryType: _deliveryType,
        orderDate: _orderDate,
      );

      if (mounted) {
        _snack('Order #${result['order_id']} created ✓', success: true);
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
                          _buildCustomerSection(),
                          const SizedBox(height: 20),
                          _buildCashSection(),
                          const SizedBox(height: 20),
                          _buildOrderDateSection(),
                          const SizedBox(height: 20),
                          _buildDeliverySection(),
                          const SizedBox(height: 20),
                          _buildStatusSection(),
                          const SizedBox(height: 20),
                          _buildItemsSection(),
                          const SizedBox(height: 20),
                          _buildSummaryCard(),
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
                border:
                    Border.all(color: const Color(0xFF2A3040), width: 1),
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
                  "New Order",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "Fill in the order details",
                  style:
                      TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────
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

  // ── Customer ──────────────────────────────────────────────
  Widget _buildCustomerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('CUSTOMER'),
        GestureDetector(
          onTap: _selectCustomerSheet,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedCustomer != null
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
                  child: const Icon(Icons.person_rounded,
                      color: Color(0xFF6C63FF), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedCustomer == null
                      ? const Text(
                          'Select customer...',
                          style: TextStyle(
                              color: Color(0xFF4A5568), fontSize: 14),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCustomer!['name'] ?? '-',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_selectedCustomer!['phone'] != null)
                              Text(
                                _selectedCustomer!['phone'],
                                style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12),
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

  // ── Cash ──────────────────────────────────────────────────
  Widget _buildCashSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('CASH ACCOUNT'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF222840), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Map<String, dynamic>>(
              value: _selectedCash,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E2333),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF4A5568)),
              style:
                  const TextStyle(color: Colors.white, fontSize: 14),
              hint: const Text('Select cash...',
                  style: TextStyle(color: Color(0xFF4A5568))),
              items:
                  _cashes.map<DropdownMenuItem<Map<String, dynamic>>>((c) {
                return DropdownMenuItem(
                  value: c as Map<String, dynamic>,
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 10),
                      Text(c['name'] ?? '-'),
                      const Spacer(),
                      Text(
                        'Rp ${_formatPrice(double.tryParse(c['balance']?.toString() ?? '0') ?? 0)}',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedCash = v),
            ),
          ),
        ),
      ],
    );
  }

  // ── Order Date ────────────────────────────────────────────
  Widget _buildOrderDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ORDER DATE & TIME'),
        GestureDetector(
          onTap: _pickOrderDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFF222840), width: 1),
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
                        _formatOrderDate(_orderDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _formatUtcLabel(_orderDate),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
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

  // ── Delivery ──────────────────────────────────────────────
  Widget _buildDeliverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('DELIVERY'),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: const Color(0xFF222840), width: 1),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    _deliveryToggle(
                        'pickup', Icons.store_rounded, 'Pickup'),
                    const SizedBox(width: 6),
                    _deliveryToggle('delivery',
                        Icons.delivery_dining_rounded, 'Delivery'),
                  ],
                ),
              ),
              if (_deliveryType == 'delivery')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      const Text(
                        'Delivery fee',
                        style: TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _deliveryPriceController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                            prefixText: 'Rp ',
                            prefixStyle: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (v) {
                            setState(
                                () => _deliveryPrice =
                                    double.tryParse(v) ?? 0);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _deliveryToggle(String type, IconData icon, String label) {
    final active = _deliveryType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _deliveryType = type;
          if (type == 'pickup') {
            _deliveryPrice = 0;
            _deliveryPriceController.text = '0';
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF1E1B4B)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? const Color(0xFF6C63FF).withOpacity(0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
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
        ),
      ),
    );
  }

  // ── Status ────────────────────────────────────────────────
  Widget _buildStatusSection() {
    const statuses = [
      'pending',
      'prepared',
      'paid',
      'picked up',
      'delivered'
    ];
    const colors = {
      'pending': Color(0xFFF59E0B),
      'prepared': Color(0xFF6C63FF),
      'paid': Color(0xFF10B981),
      'picked up': Color(0xFF10B981),
      'delivered': Color(0xFF10B981),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ORDER STATUS'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: const Color(0xFF222840), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _status,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E2333),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF4A5568)),
              items: statuses.map((s) {
                final color = colors[s] ?? const Color(0xFF94A3B8);
                return DropdownMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        s[0].toUpperCase() + s.substring(1),
                        style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) =>
                  setState(() => _status = v ?? 'pending'),
            ),
          ),
        ),
      ],
    );
  }

  // ── Items ─────────────────────────────────────────────────
  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionLabel('ORDER ITEMS')),
            GestureDetector(
              onTap: _addProductSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          const Color(0xFF6C63FF).withOpacity(0.3)),
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
        if (_orderItems.isEmpty)
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFF222840), width: 1),
            ),
            child: const Center(
              child: Text(
                'No items added yet',
                style:
                    TextStyle(color: Color(0xFF4A5568), fontSize: 13),
              ),
            ),
          )
        else
          ...List.generate(_orderItems.length, (i) {
            final item = _orderItems[i];
            final product = item['product'] as Map<String, dynamic>;
            final variant = item['variant'] as Map<String, dynamic>;
            final qty = item['qty'] as double;
            final sellPrice =
                double.tryParse(item['sell_price']?.toString() ?? '0') ??
                    0;
            final subtotal = sellPrice * qty;

            final qtyCtrl = TextEditingController(
              text: qty % 1 == 0
                  ? qty.toInt().toString()
                  : qty.toStringAsFixed(2),
            );
            final priceCtrl = TextEditingController(
              text: sellPrice > 0 ? sellPrice.toInt().toString() : '',
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161B27),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF222840), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Product / variant name row ──────────
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B4B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                            Icons.inventory_2_rounded,
                            color: Color(0xFF6C63FF),
                            size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? '-',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700),
                            ),
                            Text(
                              variant['name'] ?? '-',
                              style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _orderItems.removeAt(i)),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Color(0xFFEF4444), size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Qty stepper + sell price input ──────
                  Row(
                    children: [
                      // Qty stepper
                      Row(
                        children: [
                          _qtyBtn(Icons.remove_rounded, () {
                            setState(() {
                              final newQty = double.parse(
                                ((qty - 0.01) < 0.01
                                        ? 0.01
                                        : qty - 0.01)
                                    .toStringAsFixed(2),
                              );
                              if (qty <= 0.01) {
                                _orderItems.removeAt(i);
                              } else {
                                _orderItems[i]['qty'] = newQty;
                              }
                            });
                          }),
                          SizedBox(
                            width: 52,
                            child: TextField(
                              controller: qtyCtrl,
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
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
                                  setState(() =>
                                      _orderItems[i]['qty'] =
                                          double.parse(parsed
                                              .toStringAsFixed(2)));
                                }
                              },
                              onSubmitted: (v) {
                                final parsed = double.tryParse(v);
                                if (parsed == null || parsed <= 0) {
                                  setState(() =>
                                      _orderItems.removeAt(i));
                                }
                              },
                            ),
                          ),
                          _qtyBtn(Icons.add_rounded, () {
                            setState(() =>
                                _orderItems[i]['qty'] = double.parse(
                                    (qty + 0.01).toStringAsFixed(2)));
                          }),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // ── Sell price input ─────────────────
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1117),
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF222840),
                                width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sell Price',
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
                                            color:
                                                Color(0xFF2A3040),
                                            fontSize: 13),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding:
                                            EdgeInsets.zero,
                                      ),
                                      onChanged: (v) {
                                        setState(() =>
                                            _orderItems[i]
                                                ['sell_price'] =
                                                double.tryParse(
                                                        v) ??
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

                      // ── Subtotal ─────────────────────────
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

  // ── Summary ───────────────────────────────────────────────
  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222840), width: 1),
      ),
      child: Column(
        children: [
          _summaryRow('Items total',
              'Rp ${_formatPrice(_itemsTotal)}', Colors.white),
          if (_deliveryType == 'delivery') ...[
            const SizedBox(height: 8),
            _summaryRow('Delivery fee',
                'Rp ${_formatPrice(_deliveryPrice)}',
                const Color(0xFF64748B)),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFF222840), height: 1),
          ),
          _summaryRow(
            'Grand total',
            'Rp ${_formatPrice(_grandTotal)}',
            const Color(0xFF10B981),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor,
          {bool bold = false}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: bold
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                fontSize: bold ? 14 : 13,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.normal,
              )),
          Text(value,
              style: TextStyle(
                color: valueColor,
                fontSize: bold ? 16 : 13,
                fontWeight: FontWeight.w800,
              )),
        ],
      );

  // ── Submit button ─────────────────────────────────────────
  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: _submitting ? null : _submit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.35),
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
                : const Text(
                    'Create Order',
                    style: TextStyle(
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