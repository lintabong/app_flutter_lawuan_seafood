import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ReportPage extends StatefulWidget {
  @override
  State<ReportPage> createState() => _ReportPageState();
}

enum _Period { today, week, month, custom }

class _ReportPageState extends State<ReportPage> {
  bool loading = true;
  Map<String, dynamic> summary = {};
  List productSales = [];

  _Period period = _Period.today;
  late DateTime rangeStart;
  late DateTime rangeEnd; // exclusive (half-open range)

  final Set<int> _expanded = {};

  static const Color _pink   = Color(0xFFEC4899);
  static const Color _pinkBg = Color(0xFF2D0A1E);

  @override
  void initState() {
    super.initState();
    _setPeriod(_Period.today);
  }

  // ── Range calculation ────────────────────────────────────

  void _computeRange(_Period p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (p) {
      case _Period.today:
        rangeStart = today;
        rangeEnd   = today.add(const Duration(days: 1));
        break;
      case _Period.week:
        final start = today.subtract(Duration(days: today.weekday - 1)); // Monday
        rangeStart = start;
        rangeEnd   = start.add(const Duration(days: 7));
        break;
      case _Period.month:
        rangeStart = DateTime(today.year, today.month, 1);
        rangeEnd   = DateTime(today.year, today.month + 1, 1);
        break;
      case _Period.custom:
        // kept from date range picker
        break;
    }
  }

  Future<void> _setPeriod(_Period p) async {
    setState(() {
      period = p;
      _computeRange(p);
    });
    await _load();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: rangeStart,
        end: rangeEnd.subtract(const Duration(days: 1)),
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: _pink,
            surface: const Color(0xFF161B27),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF161B27),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        period = _Period.custom;
        rangeStart = DateTime(picked.start.year, picked.start.month, picked.start.day);
        rangeEnd = DateTime(picked.end.year, picked.end.month, picked.end.day)
            .add(const Duration(days: 1)); // half-open, inklusif hari terakhir
      });
      await _load();
    }
  }

  // ── Data load ─────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { loading = true; _expanded.clear(); });
    final results = await Future.wait([
      SupabaseService.getSalesSummary(start: rangeStart, end: rangeEnd),
      SupabaseService.getProductSales(start: rangeStart, end: rangeEnd),
    ]);
    setState(() {
      summary = results[0] as Map<String, dynamic>;
      productSales = results[1] as List;
      loading = false;
    });
  }

  // ── Helpers ──────────────────────────────────────────────

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num = double.tryParse(price.toString()) ?? 0;
    final str = num.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _formatQty(dynamic qty) {
    final n = double.tryParse(qty.toString()) ?? 0;
    if (n % 1 == 0) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }

  String _formatFullDate(DateTime d) {
    const months = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  String _rangeLabel() {
    final lastDay = rangeEnd.subtract(const Duration(days: 1));
    if (rangeStart.year == lastDay.year &&
        rangeStart.month == lastDay.month &&
        rangeStart.day == lastDay.day) {
      return _formatFullDate(rangeStart);
    }
    return "${_formatFullDate(rangeStart)} — ${_formatFullDate(lastDay)}";
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildPeriodBar(),
            Expanded(
              child: loading
                  ? _buildLoading()
                  : RefreshIndicator(
                      color: _pink,
                      backgroundColor: const Color(0xFF161B27),
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                        children: [
                          _buildSummaryGrid(),
                          const SizedBox(height: 20),
                          _buildProductHeader(),
                          const SizedBox(height: 10),
                          if (productSales.isEmpty)
                            _emptyProducts()
                          else
                            ...productSales.asMap().entries.map(
                              (e) => _buildProductCard(e.key, e.value as Map),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
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
              width: 40, height: 40,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Sales Report", style: TextStyle(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800, letterSpacing: -0.5,
                )),
                if (!loading)
                  Text("${productSales.length} products active",
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ),
          GestureDetector(
            onTap: loading ? null : _load,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _pinkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _pink.withOpacity(0.3), width: 1),
              ),
              child: const Icon(Icons.refresh_rounded, color: _pink, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Period bar ────────────────────────────────────────────

  Widget _buildPeriodBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _periodChip("Today", _Period.today),
              const SizedBox(width: 8),
              _periodChip("This Week", _Period.week),
              const SizedBox(width: 8),
              _periodChip("This Month", _Period.month),
              const SizedBox(width: 8),
              _customChip(),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF222840), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: _pinkBg, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.calendar_today_rounded,
                      size: 15, color: _pink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _rangeLabel(),
                    style: const TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, _Period p) {
    final active = period == p;
    return GestureDetector(
      onTap: () => _setPeriod(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? _pinkBg : const Color(0xFF161B27),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? _pink.withOpacity(0.4) : const Color(0xFF222840),
              width: 1),
        ),
        child: Text(label, style: TextStyle(
          color: active ? _pink : const Color(0xFF94A3B8),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        )),
      ),
    );
  }

  Widget _customChip() {
    final active = period == _Period.custom;
    return GestureDetector(
      onTap: _pickCustomRange,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: active ? _pinkBg : const Color(0xFF161B27),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? _pink.withOpacity(0.4) : const Color(0xFF222840),
              width: 1),
        ),
        child: Icon(Icons.tune_rounded,
            size: 16, color: active ? _pink : const Color(0xFF94A3B8)),
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 36, height: 36,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: _pink)),
          const SizedBox(height: 16),
          const Text("Crunching the numbers...",
              style: TextStyle(
                  color: Color(0xFF4A5568), fontSize: 14)),
        ],
      ),
    );
  }

  // ── Summary grid ──────────────────────────────────────────

  Widget _buildSummaryGrid() {
    final totalRevenue   = _num(summary['total_revenue']);
    final grossProfit    = _num(summary['gross_profit']);
    final orderCount     = _num(summary['order_count']).toInt();
    final totalCogs      = _num(summary['total_cogs']);
    final totalExpense   = _num(summary['total_expense']);
    final totalPurchase  = _num(summary['total_purchase']);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _summaryTile("Revenue", _formatPrice(totalRevenue),
                const Color(0xFF10B981), const Color(0xFF062318),
                Icons.trending_up_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _summaryTile("Gross Profit", _formatPrice(grossProfit),
                const Color(0xFF6C63FF), const Color(0xFF1E1B4B),
                Icons.savings_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _summaryTile("Orders", orderCount.toString(),
                const Color(0xFF06B6D4), const Color(0xFF0C2A3A),
                Icons.receipt_long_rounded)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _summaryTile("COGS", _formatPrice(totalCogs),
                const Color(0xFFF97316), const Color(0xFF2D1200),
                Icons.inventory_2_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _summaryTile("Expense", _formatPrice(totalExpense),
                const Color(0xFFEF4444), const Color(0xFF2D0A0A),
                Icons.arrow_upward_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _summaryTile("Purchase", _formatPrice(totalPurchase),
                const Color(0xFFF59E0B), const Color(0xFF2D1F0A),
                Icons.shopping_bag_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _summaryTile(String label, String value,
      Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF222840), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis),
          Text(label, style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Product list ──────────────────────────────────────────

  Widget _buildProductHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Product Performance", style: TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        Text("${productSales.length} items", style: const TextStyle(
            color: Color(0xFF64748B), fontSize: 12.5)),
      ],
    );
  }

  Widget _emptyProducts() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.bar_chart_rounded,
              color: Color(0xFF2A3040), size: 56),
          const SizedBox(height: 12),
          const Text("No sales or purchases in this period",
              style: TextStyle(color: Color(0xFF4A5568), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildProductCard(int index, Map p) {
    final profit    = _num(p['profit']);
    final revenue   = _num(p['revenue']);
    final cost      = _num(p['cost']);
    final qtySold   = _num(p['qty_sold_kg']);
    final qtyPurch  = _num(p['qty_purchased_kg']);
    final purchAmt  = _num(p['purchase_amount']);
    final orderCnt  = _num(p['order_count']).toInt();
    final unit      = p['unit']?.toString() ?? 'kg';
    final isProfitPositive = profit >= 0;
    final color = revenue > 0
        ? (isProfitPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444))
        : const Color(0xFFF97316);
    final bg = revenue > 0
        ? (isProfitPositive ? const Color(0xFF062318) : const Color(0xFF2D0A0A))
        : const Color(0xFF2D1200);
    final isExpanded = _expanded.contains(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded ? color.withOpacity(0.25) : const Color(0xFF222840),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              splashColor: color.withOpacity(0.06),
              onTap: () => setState(() {
                if (isExpanded) { _expanded.remove(index); }
                else { _expanded.add(index); }
              }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: bg, borderRadius: BorderRadius.circular(13)),
                      child: Icon(
                          revenue > 0
                              ? Icons.point_of_sale_rounded
                              : Icons.shopping_bag_rounded,
                          color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['product_name']?.toString() ?? '—',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.scale_rounded,
                                  size: 11, color: Color(0xFF4A5568)),
                              const SizedBox(width: 4),
                              Text("${_formatQty(qtySold)} $unit sold",
                                  style: const TextStyle(
                                      color: Color(0xFF4A5568), fontSize: 12)),
                              const SizedBox(width: 10),
                              const Icon(Icons.receipt_rounded,
                                  size: 11, color: Color(0xFF4A5568)),
                              const SizedBox(width: 4),
                              Text("$orderCnt orders",
                                  style: const TextStyle(
                                      color: Color(0xFF4A5568), fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Rp ${_formatPrice(revenue)}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          "${isProfitPositive ? '+' : '−'}Rp ${_formatPrice(profit.abs())}",
                          style: TextStyle(
                              color: color, fontSize: 12.5,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF4A5568), size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            _buildProductDetail(
              cost: cost,
              qtyPurch: qtyPurch,
              purchAmt: purchAmt,
              unit: unit,
            ),
        ],
      ),
    );
  }

  Widget _buildProductDetail({
    required double cost,
    required double qtyPurch,
    required double purchAmt,
    required String unit,
  }) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          height: 1,
          color: const Color(0xFF222840),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow("Cost of goods sold", "Rp ${_formatPrice(cost)}"),
              const SizedBox(height: 8),
              _detailRow("Qty purchased", "${_formatQty(qtyPurch)} $unit"),
              const SizedBox(height: 8),
              _detailRow("Purchase amount", "Rp ${_formatPrice(purchAmt)}"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2333), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(
              color: Color(0xFF94A3B8), fontSize: 13)),
          Text(value, style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}