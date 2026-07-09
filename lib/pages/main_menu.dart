import 'dart:async';

import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../pages/cash_out_page.dart';
import 'convert_variant_page.dart';
import 'convert_product_page.dart';
import 'create_order_page.dart';
import 'customers_page.dart';
import 'delivery_order_page.dart';
import 'order_page.dart';
import 'product_page.dart';
import 'purchase_product.dart';
import 'supplier_page.dart';
import 'transaction_page.dart';
import 'report_page.dart';
import 'stock_opname_page.dart';
import 'driver_shipment_page.dart';
import 'task_shipment_page.dart';

import '../helpers/currency_utils.dart';

class MainMenu extends StatefulWidget {
  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  // ── Profile (hardcoded for now) ────────────────────────────────────────
  final String _userName = 'Admin';
  final String _userRole = 'Administrator';

  // ── Balance & total stock ──────────────────────────────────────────────
  String _revenue = 'Rp 0';
  String _totalStockKg = '0 kg';
  bool _loading = true;
  bool _hideBalance = false;

  // ── Account box tabs: 0=Balance, 1=Stock, 2=Items, 3=Cash ──────────────
  int _tab = 0;

  // Stock tracking (pending+prepared / paid / stock)
  List<dynamic> _stockList = [];
  bool _stockLoading = true;

  // Item report (per product, 7 days)
  List<dynamic> _itemList = [];
  bool _itemLoading = true;

  // Cash report (sales summary, 7 days)
  Map<String, dynamic> _cash = {};
  bool _cashLoading = true;

  final ScrollController _stockCtrl = ScrollController();
  final ScrollController _itemCtrl = ScrollController();
  final ScrollController _cashCtrl = ScrollController();

  Timer? _refreshTimer;

  final List<Map<String, dynamic>> menus = [
    {'title': 'Orders', 'icon': Icons.receipt_long_rounded, 'color': Color(0xFFF59E0B), 'bg': Color(0xFF2D1F0A)},
    {'title': 'Delivery Orders', 'icon': Icons.local_shipping_rounded, 'color': Color(0xFF3B82F6), 'bg': Color(0xFF0B1D3A)},
    {'title': 'Track Driver', 'icon': Icons.local_shipping_rounded, 'color': Color(0xFF3B82F6), 'bg': Color(0xFF0B1D3A)},
    {'title': 'My Tasks', 'icon': Icons.route_rounded, 'color': Color(0xFF10B981), 'bg': Color(0xFF062318)},
    {'title': 'Create Order', 'icon': Icons.add_circle_rounded, 'color': Color(0xFF10B981), 'bg': Color(0xFF062318)},
    {'title': 'Products', 'icon': Icons.inventory_2_rounded, 'color': Color(0xFF6C63FF), 'bg': Color(0xFF1E1B4B)},
    {'title': 'Customers', 'icon': Icons.people_alt_rounded, 'color': Color(0xFF06B6D4), 'bg': Color(0xFF0C2A3A)},
    {'title': 'Suppliers', 'icon': Icons.store_rounded, 'color': Color(0xFF14B8A6), 'bg': Color(0xFF06231F)},
    {'title': 'Transaction', 'icon': Icons.account_balance_wallet_rounded, 'color': Color(0xFFEC4899), 'bg': Color(0xFF2D0A1E)},
    {'title': 'Product Purchase', 'icon': Icons.shopping_bag_rounded, 'color': Color(0xFFF97316), 'bg': Color(0xFF2D1200)},
    {'title': 'Cash Out', 'icon': Icons.money_off_csred_rounded, 'color': Color(0xFFEF4444), 'bg': Color(0xFF2A0B0B)},
    {'title': 'Write On', 'icon': Icons.playlist_add_rounded, 'color': Color(0xFF22C55E), 'bg': Color(0xFF07230F)},
    {'title': 'Write Off', 'icon': Icons.playlist_remove_rounded, 'color': Color(0xFFF43F5E), 'bg': Color(0xFF2A0B12)},
    {'title': 'Convert Variant', 'icon': Icons.swap_horiz_rounded, 'color': Color(0xFF8B5CF6), 'bg': Color(0xFF1C1030)},
    {'title': 'Convert Product', 'icon': Icons.sync_alt_rounded, 'color': Color.fromARGB(255, 92, 246, 179), 'bg': Color(0xFF0A2A20)},
    {'title': 'Stock Opname', 'icon': Icons.fact_check_rounded, 'color': Color.fromARGB(255, 199, 155, 73), 'bg': Color(0xFF2A2410)},
    {'title': 'Report', 'icon': Icons.bar_chart_rounded, 'color': Color(0xFF8B5CF6), 'bg': Color(0xFF1C1030)},

  ];

  @override
  void initState() {
    super.initState();
    _refreshAll();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 150),
      (_) => _refreshAll(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _stockCtrl.dispose();
    _itemCtrl.dispose();
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshAll({bool silent = false}) async {
    await Future.wait([
      _fetchDashboardData(silent: silent),
      _fetchStock(silent: silent),
      _fetchItems(silent: silent),
      _fetchCash(silent: silent),
    ]);
  }

  ({DateTime start, DateTime end}) _last7Days() {
    final now = DateTime.now();
    return (start: now.subtract(const Duration(days: 7)), end: now);
  }

  String _formatKg(double kg) {
    final s = kg % 1 == 0 ? kg.toInt().toString() : kg.toStringAsFixed(2);
    return '$s kg';
  }

  String _fmtNum(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  double _toD(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

  Future<void> _fetchDashboardData({bool silent = false}) async {
    try {
      final results = await Future.wait([
        SupabaseService.getCashBalance(1),
        SupabaseService.getTotalStockKg(),
      ]);
      if (!mounted) return;
      setState(() {
        _revenue = CurrencyUtils.formatRupiah(results[0]);
        _totalStockKg = _formatKg(results[1]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _loading = false);
    }
  }

  Future<void> _fetchStock({bool silent = false}) async {
    try {
      final list = await SupabaseService.getStockTracking();
      if (!mounted) return;
      setState(() {
        _stockList = list;
        _stockLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _stockLoading = false);
    }
  }

  Future<void> _fetchItems({bool silent = false}) async {
    try {
      final r = _last7Days();
      final res = await SupabaseService.getProductSales(start: r.start, end: r.end);
      if (!mounted) return;
      setState(() {
        _itemList = res;
        _itemLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _itemLoading = false);
    }
  }

  Future<void> _fetchCash({bool silent = false}) async {
    try {
      final r = _last7Days();
      final res = await SupabaseService.getSalesSummary(start: r.start, end: r.end);
      if (!mounted) return;
      setState(() {
        _cash = res;
        _cashLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _cashLoading = false);
    }
  }

  void _navigate(String title) {
    Widget? page;
    switch (title) {
      case 'Products':
        page = ProductPage();
        break;
      case 'Orders':
        page = OrderPage();
        break;
      case 'Transaction':
        page = TransactionPage();
        break;
      case 'Delivery Orders':
        page = DeliveryOrderPage();
        break;
      case 'Create Order':
        page = CreateOrderPage();
        break;
      case 'Product Purchase':
        page = ProductPurchasePage();
        break;
      case 'Customers':
        page = CustomerPage();
        break;
      case 'Suppliers':
        page = SupplierPage();
        break;
      case 'Cash Out':
        page = CashOutPage();
        break;
      case 'Convert Variant':
        page = ConvertVariantPage();
        break;
      case 'Convert Product':
        page = ConvertProductPage();
        break;
      case 'Report':
        page = ReportPage();
        break;
      case 'Stock Opname':
        page = StockOpnamePage();
        break;
      case 'Track Driver':
        page = DriverShipmentPage();
        break;
      case 'My Tasks':
        page = TaskShipmentPage();
        break;
      default:
        _snack('"$title" is not available yet');
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1E2333),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF161B27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to log out?',
            style: TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Log Out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      // Your app's auth listener handles redirect to the login screen.
      await SupabaseService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F1117),
      body: SafeArea(
        child: RefreshIndicator(
          color: Color(0xFF6C63FF),
          backgroundColor: Color(0xFF161B27),
          onRefresh: () => _refreshAll(),
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  SizedBox(height: 22),
                  _buildAccountBox(),
                  SizedBox(height: 18),
                  _buildMenuBox(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile header ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    final initials = _userName
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                _userRole,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        _headerIcon(Icons.notifications_none_rounded,
            onTap: () => _snack('No new notifications'), dot: true),
        SizedBox(width: 6),
        _headerIcon(Icons.settings_outlined, onTap: () => _snack('Settings are not available yet')),
        SizedBox(width: 6),
        _headerIcon(Icons.logout_rounded, onTap: _confirmLogout, color: Color(0xFFF87171)),
      ],
    );
  }

  Widget _headerIcon(IconData icon, {required VoidCallback onTap, bool dot = false, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFF2A3040), width: 1),
            ),
            child: Icon(icon, color: color ?? Color(0xFFCBD5E1), size: 20),
          ),
          if (dot)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFF1A1F2E), width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Account box (tabs: Balance / Stock / Items / Cash) ─────────────────
  Widget _buildAccountBox() {
    final accent = Color(0xFF6C63FF);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Color(0xFF161B27),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Color(0xFF222840), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Accounts',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              Spacer(),
              GestureDetector(
                onTap: () => setState(() => _hideBalance = !_hideBalance),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(
                      _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: accent,
                      size: 17,
                    ),
                    SizedBox(width: 5),
                    Text(
                      _hideBalance ? 'Show' : 'Hide',
                      style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              _tabButton(0, Icons.account_balance_wallet_rounded, 'Balance'),
              _tabButton(1, Icons.inventory_2_rounded, 'Stock'),
              _tabButton(2, Icons.insights_rounded, 'Items'),
              _tabButton(3, Icons.payments_rounded, 'Cash'),
            ],
          ),
          SizedBox(height: 12),
          Divider(color: Color(0xFF222840), height: 1),
          SizedBox(height: 14),
          SizedBox(
            height: 196,
            child: IndexedStack(
              index: _tab,
              children: [
                _buildBalanceTab(),
                _buildStockTab(),
                _buildItemsTab(),
                _buildCashTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(int index, IconData icon, String label) {
    final selected = _tab == index;
    final accent = Color(0xFF6C63FF);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? accent.withOpacity(0.15) : Color(0xFF1A1F2E),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selected ? accent.withOpacity(0.5) : Color(0xFF222840),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: selected ? accent : Color(0xFF94A3B8), size: 20),
            ),
            SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Color(0xFF94A3B8),
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Container(
              width: 20,
              height: 2.5,
              decoration: BoxDecoration(
                color: selected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tab 1: Balance (with hide toggle) + total stock
  Widget _buildBalanceTab() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: _loading
          ? Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Cash Balance',
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w500)),
                SizedBox(height: 6),
                Text(
                  _hideBalance ? 'Rp ' + '\u2022' * 7 : _revenue,
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                SizedBox(height: 16),
                Divider(color: Colors.white.withOpacity(0.2), height: 1),
                SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.scale_rounded, color: Colors.white.withOpacity(0.85), size: 16),
                        SizedBox(width: 6),
                        Text('Total Stock',
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Text(_totalStockKg,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
    );
  }

  // Tab 2: Stock tracking — pending+prepared / paid / stock (no unit)
  Widget _buildStockTab() {
    if (_stockLoading) return _tabLoader();
    if (_stockList.isEmpty) return _tabEmpty('No stock data');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 10, left: 2, right: 2),
          child: Row(
            children: [
              _legend(Color(0xFFF59E0B), 'Pending'),
              SizedBox(width: 14),
              _legend(Color(0xFF8B5CF6), 'Paid'),
              SizedBox(width: 14),
              _legend(Color(0xFFCBD5E1), 'Stock'),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _stockCtrl,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _stockCtrl,
              padding: EdgeInsets.only(right: 10),
              itemCount: _stockList.length,
              separatorBuilder: (_, __) => Divider(color: Color(0xFF222840), height: 14),
              itemBuilder: (context, i) {
                final r = _stockList[i] as Map<String, dynamic>;
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        r['product_name']?.toString() ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(width: 8),
                    _numCell(_toD(r['pending_prepared_kg']), Color(0xFFF59E0B)),
                    _numCell(_toD(r['paid_kg']), Color(0xFF8B5CF6)),
                    _numCell(_toD(r['stock_kg']), Color(0xFFE2E8F0)),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _numCell(double v, Color c) => SizedBox(
        width: 46,
        child: Text(
          _fmtNum(v),
          textAlign: TextAlign.right,
          style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w800),
        ),
      );

  Widget _legend(Color c, String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          SizedBox(width: 5),
          Text(t, style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      );

  // Tab 3: Item report (per product, 7 days)
  Widget _buildItemsTab() {
    if (_itemLoading) return _tabLoader();
    if (_itemList.isEmpty) return _tabEmpty('No sales in the last 7 days');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sevenDayLabel(),
        Expanded(
          child: Scrollbar(
            controller: _itemCtrl,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _itemCtrl,
              padding: EdgeInsets.only(right: 10),
              itemCount: _itemList.length,
              separatorBuilder: (_, __) => Divider(color: Color(0xFF222840), height: 14),
              itemBuilder: (context, i) {
                final r = _itemList[i] as Map<String, dynamic>;
                final revenue = _toD(r['revenue']);
                final profit = _toD(r['profit']);
                final qty = _toD(r['qty_sold_kg']);
                final orders = (r['order_count'] as num?)?.toInt() ?? 0;
                final positive = profit >= 0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['product_name']?.toString() ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 3),
                          Text('${_formatKg(qty)} · $orders orders',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(CurrencyUtils.formatRupiah(revenue),
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text(
                          '${positive ? '+' : '-'}${CurrencyUtils.formatRupiah(profit.abs())}',
                          style: TextStyle(
                            color: positive ? Color(0xFF34D399) : Color(0xFFF87171),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Tab 4: Cash report (sales summary, 7 days)
  Widget _buildCashTab() {
    if (_cashLoading) return _tabLoader();
    if (_cash.isEmpty) return _tabEmpty('No cash data');

    final orderCount = (_cash['order_count'] as num?)?.toInt() ?? 0;
    final grossProfit = _toD(_cash['gross_profit']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sevenDayLabel(),
        Expanded(
          child: Scrollbar(
            controller: _cashCtrl,
            thumbVisibility: true,
            child: ListView(
              controller: _cashCtrl,
              padding: EdgeInsets.only(right: 10),
              children: [
                _cashRow('Orders', '$orderCount'),
                _cashRow('Items Revenue', CurrencyUtils.formatRupiah(_toD(_cash['items_revenue']))),
                _cashRow('Delivery Revenue', CurrencyUtils.formatRupiah(_toD(_cash['delivery_revenue']))),
                _cashRow('Total Revenue', CurrencyUtils.formatRupiah(_toD(_cash['total_revenue'])),
                    highlight: true),
                _cashRow('COGS', CurrencyUtils.formatRupiah(_toD(_cash['total_cogs']))),
                _cashRow('Gross Profit', CurrencyUtils.formatRupiah(grossProfit),
                    highlight: true,
                    valueColor: grossProfit >= 0 ? Color(0xFF34D399) : Color(0xFFF87171)),
                _cashRow('Expense', CurrencyUtils.formatRupiah(_toD(_cash['total_expense']))),
                _cashRow('Purchase', CurrencyUtils.formatRupiah(_toD(_cash['total_purchase']))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cashRow(String label, String value, {bool highlight = false, Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? Colors.white : Color(0xFF94A3B8),
              fontSize: 12.5,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? (highlight ? Colors.white : Color(0xFFCBD5E1)),
              fontSize: highlight ? 14 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sevenDayLabel() => Padding(
        padding: EdgeInsets.only(bottom: 8, left: 2),
        child: Text('Last 7 days',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      );

  Widget _tabLoader() => Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2),
        ),
      );

  Widget _tabEmpty(String msg) =>
      Center(child: Text(msg, style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5)));

  // ── Menu box (replaces Favorite Transactions) ──────────────────────────
  Widget _buildMenuBox() {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 16, 14, 8),
      decoration: BoxDecoration(
        color: Color(0xFF161B27),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Color(0xFF222840), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('Menu',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: menus.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              return _MenuItem(
                menu: menus[index],
                onTap: () => _navigate(menus[index]['title']),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Single menu item (small icon + small text) ──────────────────────────
class _MenuItem extends StatelessWidget {
  final Map<String, dynamic> menu;
  final VoidCallback onTap;
  const _MenuItem({required this.menu, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = menu['color'] as Color;
    final bg = menu['bg'] as Color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withOpacity(0.18), width: 1),
            ),
            child: Icon(menu['icon'], color: color, size: 23),
          ),
          SizedBox(height: 7),
          Text(
            menu['title'],
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 10.5,
              height: 1.1,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}