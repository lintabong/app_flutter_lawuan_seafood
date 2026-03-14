import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ProductPage extends StatefulWidget {
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  List products = [];
  List filtered = [];
  bool loading = true;
  final TextEditingController _searchController = TextEditingController();

  Future loadProducts() async {
    final data = await SupabaseService.getProducts();
    setState(() {
      products = data;
      filtered = data;
      loading = false;
    });
  }

  void _onSearch(String query) {
    setState(() {
      filtered = query.isEmpty
          ? products
          : products.where((p) =>
              p['name'].toString().toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num = int.tryParse(price.toString()) ?? 0;
    final str = num.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  Color _stockColor(dynamic stock) {
    final s = int.tryParse(stock.toString()) ?? 0;
    if (s <= 5) return Color(0xFFEF4444);
    if (s <= 20) return Color(0xFFF59E0B);
    return Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F1117),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFF1E2333),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFF2A3040), width: 1),
                      ),
                      child: Icon(Icons.arrow_back_rounded, color: Color(0xFF94A3B8), size: 20),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Products",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (!loading)
                          Text(
                            "${filtered.length} items",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFF1E1B4B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF6C63FF).withOpacity(0.3), width: 1),
                    ),
                    child: Icon(Icons.add_rounded, color: Color(0xFF6C63FF), size: 22),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFF161B27),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Color(0xFF222840), width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search products...",
                    hintStyle: TextStyle(color: Color(0xFF4A5568), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF4A5568), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),

            // List
            Expanded(
              child: loading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Loading products...",
                            style: TextStyle(color: Color(0xFF4A5568), fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, color: Color(0xFF2A3040), size: 64),
                              SizedBox(height: 16),
                              Text(
                                "No products found",
                                style: TextStyle(color: Color(0xFF4A5568), fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            final stockColor = _stockColor(p['stock']);

                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Color(0xFF161B27),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Color(0xFF222840), width: 1),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  splashColor: Color(0xFF6C63FF).withOpacity(0.08),
                                  onTap: () {},
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Icon
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Color(0xFF1E1B4B),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            Icons.inventory_2_rounded,
                                            color: Color(0xFF6C63FF),
                                            size: 24,
                                          ),
                                        ),
                                        SizedBox(width: 14),

                                        // Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p['name'] ?? '-',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                              SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: stockColor.withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          width: 5,
                                                          height: 5,
                                                          decoration: BoxDecoration(
                                                            color: stockColor,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                        SizedBox(width: 5),
                                                        Text(
                                                          "${p['stock']} ${p['unit']}",
                                                          style: TextStyle(
                                                            color: stockColor,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Price
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "Rp ${_formatPrice(p['sell_price'])}",
                                              style: TextStyle(
                                                color: Color(0xFF10B981),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            SizedBox(height: 6),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: Color(0xFF2A3040),
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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