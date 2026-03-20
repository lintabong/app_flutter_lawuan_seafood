
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../pages/cash_out_page.dart';
import 'create_order_page.dart';
import 'customers_page.dart';
import 'delivery_order_page.dart';
import 'order_page.dart';
import 'product_page.dart';
import 'purchase_product.dart';
import 'transaction_page.dart';

import '../helpers/currency_utils.dart';

class MainMenu extends StatefulWidget {
  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  String _revenue = 'Rp 0';
  int _variantCount = 0;
  bool _loading = true;

  final List<Map<String, dynamic>> menus = [
    {'title': 'Orders', 'icon': Icons.receipt_long_rounded, 'color': Color(0xFFF59E0B), 'bg': Color(0xFF2D1F0A)},
    {'title': 'Delivery Orders', 'icon': Icons.local_shipping_rounded, 'color': Color(0xFF3B82F6), 'bg': Color(0xFF0B1D3A)},
    {'title': 'Create Order', 'icon': Icons.add_circle_rounded, 'color': Color(0xFF10B981), 'bg': Color(0xFF062318)},
    {'title': 'Products', 'icon': Icons.inventory_2_rounded, 'color': Color(0xFF6C63FF), 'bg': Color(0xFF1E1B4B)},
    {'title': 'Customers', 'icon': Icons.people_alt_rounded, 'color': Color(0xFF06B6D4), 'bg': Color(0xFF0C2A3A)},
    {'title': 'Transaction', 'icon': Icons.account_balance_wallet_rounded, 'color': Color(0xFFEC4899), 'bg': Color(0xFF2D0A1E)},
    {'title': 'Product Purchase', 'icon': Icons.shopping_bag_rounded, 'color': Color(0xFFF97316), 'bg': Color(0xFF2D1200)},
    {'title': 'Cash Out', 'icon': Icons.money_off_csred_rounded, 'color': Color(0xFFEF4444), 'bg': Color(0xFF2A0B0B)},
    {'title': 'Report', 'icon': Icons.bar_chart_rounded, 'color': Color(0xFF8B5CF6), 'bg': Color(0xFF1C1030)},
    {'title': 'Settings', 'icon': Icons.tune_rounded, 'color': Color(0xFF94A3B8), 'bg': Color(0xFF1A1F2E)},
  ];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final results = await Future.wait([
        SupabaseService.getCashBalance(1),
        SupabaseService.getActiveVariantCount(),
      ]);

      final balance = results[0] as double;
      final variantCount = results[1] as int;

      setState(() {
        _revenue = CurrencyUtils.formatRupiah(balance);
        _variantCount = variantCount;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F1117),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 32, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'What?',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(0xFF1E2333),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Color(0xFF2A3040), width: 1),
                          ),
                          child: Icon(Icons.notifications_none_rounded, color: Color(0xFF94A3B8), size: 22),
                        ),
                      ],
                    ),
                    SizedBox(height: 28),
                    Container(
                      padding: EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF6C63FF).withOpacity(0.35),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _loading
                          ? Center(
                              child: SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStat('Current Cash', _revenue),
                                _buildDivider(),
                                _buildStat('Variants', '$_variantCount'),
                              ],
                            ),
                    ),
                    SizedBox(height: 28),
                    Text(
                      'Menu',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final menu = menus[index];
                    return _MenuCard(menu: menu);
                  },
                  childCount: menus.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 36, color: Colors.white.withOpacity(0.2));
  }
}

class _MenuCard extends StatefulWidget {
  final Map<String, dynamic> menu;
  const _MenuCard({required this.menu});

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  void _navigate(BuildContext context) {
    final title = widget.menu['title'];
    if (title == 'Products') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductPage()));
    } else if (title == 'Orders') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrderPage()));
    } else if (title == 'Transaction') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionPage()));
    } else if (title == 'Delivery Orders') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryOrderPage()));
    } else if (title == 'Create Order') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateOrderPage()));
    } else if (title == 'Product Purchase') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductPurchasePage()));
    } else if (title == 'Customers') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerPage()));
    } else if (title == 'Cash Out') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CashOutPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.menu["color"] as Color;
    final bg = widget.menu["bg"] as Color;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _navigate(context);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: Duration(milliseconds: 120),
        child: Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Color(0xFF161B27),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _pressed ? color.withOpacity(0.5) : Color(0xFF222840),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.menu['icon'], color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.menu['title'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Open',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, color: color, size: 11),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
