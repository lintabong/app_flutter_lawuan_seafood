import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Track which product cards are expanded (showing variants)
  final Set<int> _expandedIds = {};
  // Track which products are loading their variants
  final Set<int> _loadingVariants = {};
  // Cache variants per product id
  final Map<int, List> _variantsCache = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future _loadProducts() async {
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
          : products
              .where((p) => p['name']
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()))
              .toList();
    });
  }

  Future _toggleExpand(int productId) async {
    if (_expandedIds.contains(productId)) {
      setState(() => _expandedIds.remove(productId));
      return;
    }
    setState(() => _expandedIds.add(productId));
    if (!_variantsCache.containsKey(productId)) {
      setState(() => _loadingVariants.add(productId));
      final variants = await SupabaseService.getProductVariants(productId);
      setState(() {
        _variantsCache[productId] = variants;
        _loadingVariants.remove(productId);
      });
    }
  }

  // ── Formatters ────────────────────────────────────────────
  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num = (double.tryParse(price.toString()) ?? 0).round();
    final str = num.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  Color _stockColor(dynamic stock) {
    final s = double.tryParse(stock.toString()) ?? 0;
    if (s <= 5) return const Color(0xFFEF4444);
    if (s <= 20) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  // ── Edit Product Modal ────────────────────────────────────
  void _showEditProduct(BuildContext context, Map product) {
    final stockCtrl = TextEditingController(
        text: product['stock']?.toString() ?? '0');
    final sellCtrl = TextEditingController(
        text: product['sell_price']?.toString() ?? '0');
    final buyCtrl = TextEditingController(
        text: product['buy_price']?.toString() ?? '0');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF161B27),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: Color(0xFF222840), width: 1),
                left: BorderSide(color: Color(0xFF222840), width: 1),
                right: BorderSide(color: Color(0xFF222840), width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3040),
                        borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product['name'] ?? 'Product',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 2),
                      const Text("Edit stock & prices",
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _editField(
                        label: "Stock",
                        controller: stockCtrl,
                        suffix: product['unit']?.toString() ?? '',
                        icon: Icons.inventory_2_rounded,
                        iconColor: const Color(0xFF6C63FF),
                      ),
                      const SizedBox(height: 12),
                      _editField(
                        label: "Sell Price",
                        controller: sellCtrl,
                        prefix: "Rp",
                        icon: Icons.sell_rounded,
                        iconColor: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 12),
                      _editField(
                        label: "Buy Price",
                        controller: buyCtrl,
                        prefix: "Rp",
                        icon: Icons.shopping_bag_rounded,
                        iconColor: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: saving
                              ? null
                              : () async {
                                  setModal(() => saving = true);
                                  try {
                                    final productId = product['id'] as int;
                                    await SupabaseService.updateProduct(
                                      productId: productId,
                                      stock: double.tryParse(stockCtrl.text) ?? 0,
                                      sellPrice: double.tryParse(sellCtrl.text) ?? 0,
                                      buyPrice: double.tryParse(buyCtrl.text) ?? 0,
                                    );
                                    final idx = products
                                        .indexWhere((p) => p['id'] == productId);
                                    if (idx != -1) {
                                      setState(() {
                                        products[idx]['stock'] =
                                            double.tryParse(stockCtrl.text) ?? 0;
                                        products[idx]['sell_price'] =
                                            double.tryParse(sellCtrl.text) ?? 0;
                                        products[idx]['buy_price'] =
                                            double.tryParse(buyCtrl.text) ?? 0;
                                        final fi = filtered.indexWhere(
                                            (p) => p['id'] == productId);
                                        if (fi != -1) filtered[fi] = products[idx];
                                      });
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted)
                                      _showSavedSnack(context, "Product updated");
                                  } catch (e) {
                                    setModal(() => saving = false);
                                    if (ctx.mounted)
                                      _showErrorSnack(ctx, "Failed: $e");
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text("Save Changes",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Edit Variant Modal ────────────────────────────────────
  void _showEditVariant(BuildContext context, int productId, Map variant) {
    final stockCtrl = TextEditingController(
        text: variant['stock']?.toString() ?? '0');
    final sellCtrl = TextEditingController(
        text: variant['sell_price']?.toString() ?? '0');
    final buyCtrl = TextEditingController(
        text: variant['buy_price']?.toString() ?? '0');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF161B27),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: Color(0xFF222840), width: 1),
                left: BorderSide(color: Color(0xFF222840), width: 1),
                right: BorderSide(color: Color(0xFF222840), width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3040),
                        borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1B4B),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text("Variant",
                              style: TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(variant['name'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      const Text("Edit stock & prices",
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _editField(
                        label: "Stock",
                        controller: stockCtrl,
                        suffix: variant['unit']?.toString() ?? '',
                        icon: Icons.inventory_2_rounded,
                        iconColor: const Color(0xFF6C63FF),
                      ),
                      const SizedBox(height: 12),
                      _editField(
                        label: "Sell Price",
                        controller: sellCtrl,
                        prefix: "Rp",
                        icon: Icons.sell_rounded,
                        iconColor: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 12),
                      _editField(
                        label: "Buy Price",
                        controller: buyCtrl,
                        prefix: "Rp",
                        icon: Icons.shopping_bag_rounded,
                        iconColor: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: saving
                              ? null
                              : () async {
                                  setModal(() => saving = true);
                                  try {
                                    final variantId = variant['id'] as int;
                                    await SupabaseService.updateProductVariant(
                                      variantId: variantId,
                                      stock: double.tryParse(stockCtrl.text) ?? 0,
                                      sellPrice: double.tryParse(sellCtrl.text) ?? 0,
                                      buyPrice: double.tryParse(buyCtrl.text) ?? 0,
                                    );
                                    if (_variantsCache.containsKey(productId)) {
                                      final vIdx = _variantsCache[productId]!
                                          .indexWhere(
                                              (v) => v['id'] == variantId);
                                      if (vIdx != -1) {
                                        setState(() {
                                          _variantsCache[productId]![vIdx]
                                              ['stock'] =
                                              double.tryParse(stockCtrl.text) ?? 0;
                                          _variantsCache[productId]![vIdx]
                                              ['sell_price'] =
                                              double.tryParse(sellCtrl.text) ?? 0;
                                          _variantsCache[productId]![vIdx]
                                              ['buy_price'] =
                                              double.tryParse(buyCtrl.text) ?? 0;
                                        });
                                      }
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted)
                                      _showSavedSnack(context, "Variant updated");
                                  } catch (e) {
                                    setModal(() => saving = false);
                                    if (ctx.mounted)
                                      _showErrorSnack(ctx, "Failed: $e");
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text("Save Changes",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Add Variant Modal ─────────────────────────────────────
  void _showAddVariant(BuildContext context, int productId) {
    final nameCtrl  = TextEditingController();
    final unitCtrl  = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final sellCtrl  = TextEditingController(text: '0');
    final buyCtrl   = TextEditingController(text: '0');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF161B27),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: Color(0xFF222840), width: 1),
                left: BorderSide(color: Color(0xFF222840), width: 1),
                right: BorderSide(color: Color(0xFF222840), width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3040),
                        borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text("New Variant",
                          style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    const Text("Add Variant",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text("Fill in the variant details",
                      style: TextStyle(
                          color: Color(0xFF64748B), fontSize: 12)),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(children: [
                    // Name field (text, no number filter)
                    _textField(
                      label: "Variant name",
                      controller: nameCtrl,
                      icon: Icons.label_rounded,
                      iconColor: const Color(0xFF6C63FF),
                    ),
                    const SizedBox(height: 12),
                    // Unit field
                    _textField(
                      label: "Unit (e.g. kg, pcs, box)",
                      controller: unitCtrl,
                      icon: Icons.straighten_rounded,
                      iconColor: const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 12),
                    _editField(
                      label: "Stock",
                      controller: stockCtrl,
                      icon: Icons.inventory_2_rounded,
                      iconColor: const Color(0xFF6C63FF),
                    ),
                    const SizedBox(height: 12),
                    _editField(
                      label: "Sell Price",
                      controller: sellCtrl,
                      prefix: "Rp",
                      icon: Icons.sell_rounded,
                      iconColor: const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 12),
                    _editField(
                      label: "Buy Price",
                      controller: buyCtrl,
                      prefix: "Rp",
                      icon: Icons.shopping_bag_rounded,
                      iconColor: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  _showErrorSnack(ctx, "Variant name is required");
                                  return;
                                }
                                setModal(() => saving = true);
                                try {
                                  final newVariant =
                                      await SupabaseService.insertProductVariant(
                                    productId: productId,
                                    name: name,
                                    unit: unitCtrl.text.trim(),
                                    stock: double.tryParse(stockCtrl.text) ?? 0,
                                    sellPrice: double.tryParse(sellCtrl.text) ?? 0,
                                    buyPrice: double.tryParse(buyCtrl.text) ?? 0,
                                  );
                                  setState(() {
                                    _variantsCache[productId] ??= [];
                                    _variantsCache[productId]!.add(newVariant);
                                  });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted)
                                    _showSavedSnack(context, "Variant added");
                                } catch (e) {
                                  setModal(() => saving = false);
                                  if (ctx.mounted)
                                    _showErrorSnack(ctx, "Failed: $e");
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text("Add Variant",
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared field widget ───────────────────────────────────
  Widget _editField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    String prefix = '',
    String suffix = '',
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222840), width: 1),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 48,
          decoration: const BoxDecoration(
            border: Border(
                right: BorderSide(color: Color(0xFF222840), width: 1)),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        if (prefix.isNotEmpty) ...[
          Text(prefix,
              style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: const TextStyle(
                  color: Color(0xFF4A5568), fontSize: 13),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (suffix.isNotEmpty) ...[
          Text(suffix,
              style: const TextStyle(
                  color: Color(0xFF4A5568),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
        ],
      ]),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222840), width: 1),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 48,
          decoration: const BoxDecoration(
            border: Border(
                right: BorderSide(color: Color(0xFF222840), width: 1)),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: const TextStyle(
                  color: Color(0xFF4A5568), fontSize: 13),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ]),
    );
  }

  void _showSavedSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded,
            color: Color(0xFF10B981), size: 16),
        const SizedBox(width: 10),
        Text(message, style: const TextStyle(fontSize: 13)),
      ]),
      backgroundColor: const Color(0xFF1E2333),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showErrorSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF2D0A0A),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2333),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF2A3040), width: 1),
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
                      const Text("Products",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          )),
                      if (!loading)
                        Text("${filtered.length} items",
                            style: const TextStyle(
                                color: Color(0xFF64748B), fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B4B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                        width: 1),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Color(0xFF6C63FF), size: 22),
                ),
              ]),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B27),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: const Color(0xFF222840), width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: "Search products...",
                    hintStyle:
                        TextStyle(color: Color(0xFF4A5568), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Color(0xFF4A5568), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: loading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 36, height: 36,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF6C63FF)),
                          ),
                          SizedBox(height: 16),
                          Text("Loading products...",
                              style: TextStyle(
                                  color: Color(0xFF4A5568), fontSize: 14)),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  color: Color(0xFF2A3040), size: 64),
                              SizedBox(height: 16),
                              Text("No products found",
                                  style: TextStyle(
                                      color: Color(0xFF4A5568), fontSize: 15)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) =>
                              _buildProductCard(context, filtered[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Product Card ──────────────────────────────────────────
  Widget _buildProductCard(BuildContext context, Map p) {
    final productId  = p['id'] as int;
    final stockColor = _stockColor(p['stock']);
    final isExpanded = _expandedIds.contains(productId);
    final isLoadingV = _loadingVariants.contains(productId);
    final variants   = _variantsCache[productId] ?? [];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded
              ? const Color(0xFF6C63FF).withOpacity(0.4)
              : const Color(0xFF222840),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Main row — tap to edit product
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              splashColor: const Color(0xFF6C63FF).withOpacity(0.08),
              onTap: () => _showEditProduct(context, p),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  // Icon
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.inventory_2_rounded,
                        color: Color(0xFF6C63FF), size: 24),
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] ?? '-',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            )),
                        const SizedBox(height: 6),
                        Row(children: [
                          // Stock badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: stockColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5, height: 5,
                                  decoration: BoxDecoration(
                                      color: stockColor,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "${p['stock']} ${p['unit'] ?? ''}",
                                  style: TextStyle(
                                      color: stockColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Buy price badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "Buy Rp ${_formatPrice(p['buy_price'])}",
                              style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),

                  // Right: sell price + variants toggle
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Rp ${_formatPrice(p['sell_price'])}",
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _toggleExpand(productId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? const Color(0xFF1E1B4B)
                                : const Color(0xFF0F1117),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: isExpanded
                                  ? const Color(0xFF6C63FF).withOpacity(0.4)
                                  : const Color(0xFF2A3040),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_tree_rounded,
                                  size: 10, color: Color(0xFF6C63FF)),
                              const SizedBox(width: 4),
                              const Text("Variants",
                                  style: TextStyle(
                                    color: Color(0xFF6C63FF),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  )),
                              const SizedBox(width: 3),
                              AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 12,
                                    color: Color(0xFF6C63FF)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ),

          // Variants panel
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _buildVariantsPanel(
                context, productId, variants, isLoadingV),
          ),
        ],
      ),
    );
  }

  // ── Variants Panel ────────────────────────────────────────
  Widget _buildVariantsPanel(
      BuildContext context, int productId, List variants, bool isLoading) {
    return Column(children: [
      const Divider(
          color: Color(0xFF222840), height: 1, indent: 16, endIndent: 16),
      if (isLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF6C63FF)),
            ),
          ),
        )
      else if (variants.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: GestureDetector(
              onTap: () => _showAddVariant(context, productId),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                      width: 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.add_rounded,
                      size: 13, color: Color(0xFF6C63FF)),
                  SizedBox(width: 5),
                  Text("Add first variant",
                      style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("VARIANTS",
                  style: TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  )),
              Row(children: [
                Text(
                    "${variants.length} variant${variants.length != 1 ? 's' : ''}",
                    style: const TextStyle(
                        color: Color(0xFF4A5568), fontSize: 10)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showAddVariant(context, productId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFF6C63FF).withOpacity(0.3),
                          width: 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.add_rounded,
                          size: 10, color: Color(0xFF6C63FF)),
                      SizedBox(width: 3),
                      Text("Add",
                          style: TextStyle(
                            color: Color(0xFF6C63FF),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          )),
                    ]),
                  ),
                ),
              ]),
            ],
          ),
        ),
        ...variants.map((v) => _buildVariantRow(context, productId, v)),
      ],
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildVariantRow(BuildContext context, int productId, Map v) {
    final stockColor = _stockColor(v['stock'] ?? 0);
    final isActive   = v['is_active'] == true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEditVariant(context, productId, v),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(children: [
            // Indent line
            Container(
              width: 2, height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF6C63FF).withOpacity(0.35)
                    : const Color(0xFF2A3040),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            // Variant icon
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1830),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.tune_rounded,
                  color: isActive
                      ? const Color(0xFF6C63FF)
                      : const Color(0xFF2A3040),
                  size: 15),
            ),
            const SizedBox(width: 10),
            // Name + stock
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(v['name'] ?? '—',
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF4A5568),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (!isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3040),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("inactive",
                            style: TextStyle(
                                color: Color(0xFF4A5568),
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(
                          color: stockColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${v['stock'] ?? 0} ${v['unit'] ?? ''}",
                      style: TextStyle(
                          color: stockColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Buy Rp ${_formatPrice(v['buy_price'])}",
                      style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 10,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ],
              ),
            ),
            // Sell price + edit hint
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Rp ${_formatPrice(v['sell_price'])}",
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const Icon(Icons.edit_rounded,
                    size: 11, color: Color(0xFF2A3040)),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}