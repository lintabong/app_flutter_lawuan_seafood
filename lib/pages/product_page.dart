// ═══════════════════════════════════════════════════════════════════
// lib/pages/product_page.dart  (ganti seluruh file)
//
// Perubahan dari versi lama:
//   1. Level product hanya menampilkan nama + sell price
//      (stock & buy price product dihilangkan dari tampilan)
//   2. Variant SELALU tampil di bawah product — tidak ada lagi
//      tombol expand "Variants", tidak ada lazy-load / cache
//      (semua di-fetch 1 query lewat getProductsWithVariants)
//   3. Edit product ATAU edit variant 'default' → satu modal yang
//      sama, menyimpan lewat RPC update_product_with_default_variant
//      sehingga products & variant default selalu sinkron
//   4. Add Variant dipertahankan + field Conversion Factor baru
//   5. Tombol "+" di header membuka CreateProductPage
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import 'create_product_page.dart';

class ProductPage extends StatefulWidget {
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  List products = [];
  List filtered = [];
  bool loading = true;
  final TextEditingController _searchController = TextEditingController();

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
    final data = await SupabaseService.getProductsWithVariants();
    if (!mounted) return;
    setState(() {
      products = data;
      filtered = data;
      loading = false;
    });
    _onSearch(_searchController.text);
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

  // ── Helpers ───────────────────────────────────────────────
  /// Variant milik product, urut: default paling atas, sisanya A-Z.
  List<Map<String, dynamic>> _variantsOf(Map p) {
    final raw = p['product_variants'];
    if (raw == null) return [];
    final list = List<Map<String, dynamic>>.from(raw as List);
    list.sort((a, b) {
      if (a['name'] == 'default') return -1;
      if (b['name'] == 'default') return 1;
      return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
    });
    return list;
  }

  Map<String, dynamic>? _defaultOf(Map p) {
    final list =
        _variantsOf(p).where((v) => v['name'] == 'default').toList();
    return list.isNotEmpty ? list.first : null;
  }

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

  String _formatFactor(dynamic f) {
    final v = double.tryParse(f?.toString() ?? '1') ?? 1;
    var s = v.toStringAsFixed(4);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  Color _stockColor(dynamic stock) {
    final s = double.tryParse(stock.toString()) ?? 0;
    if (s <= 5) return const Color(0xFFEF4444);
    if (s <= 20) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  // ── Edit Product / Default Variant (SINKRON via RPC) ──────
  // Dipanggil baik dari tap product maupun tap variant 'default'.
  // Nilai awal diambil dari variant default (sumber kebenaran).
  void _showEditSynced(BuildContext context, Map product) {
    final def = _defaultOf(product);
    if (def == null) {
      _showErrorSnack(context,
          'Product ini tidak punya variant "default", tidak bisa diedit sinkron');
      return;
    }

    final stockCtrl =
        TextEditingController(text: def['stock']?.toString() ?? '0');
    final sellCtrl =
        TextEditingController(text: def['sell_price']?.toString() ?? '0');
    final buyCtrl =
        TextEditingController(text: def['buy_price']?.toString() ?? '0');
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
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 36,
                      height: 4,
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
                            color: const Color(0xFF062318),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text("Product + default",
                              style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(product['name'] ?? 'Product',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      const Text(
                          "Product & default variant akan terupdate bersamaan",
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
                        suffix: def['unit']?.toString() ??
                            product['unit']?.toString() ??
                            '',
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
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
                                    final newStock =
                                        double.tryParse(stockCtrl.text) ?? 0;
                                    final newSell =
                                        double.tryParse(sellCtrl.text) ?? 0;
                                    final newBuy =
                                        double.tryParse(buyCtrl.text) ?? 0;

                                    await SupabaseService
                                        .updateProductWithDefaultVariant(
                                      productId: productId,
                                      stock: newStock,
                                      sellPrice: newSell,
                                      buyPrice: newBuy,
                                    );

                                    // Update state lokal: product + default
                                    setState(() {
                                      final idx = products.indexWhere(
                                          (p) => p['id'] == productId);
                                      if (idx != -1) {
                                        products[idx]['sell_price'] = newSell;
                                        final vs = products[idx]
                                            ['product_variants'] as List?;
                                        if (vs != null) {
                                          for (final v in vs) {
                                            if (v['name'] == 'default') {
                                              v['stock'] = newStock;
                                              v['sell_price'] = newSell;
                                              v['buy_price'] = newBuy;
                                            }
                                          }
                                        }
                                      }
                                    });

                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      _showSavedSnack(context,
                                          "Product & default variant updated");
                                    }
                                  } catch (e) {
                                    setModal(() => saving = false);
                                    if (ctx.mounted) {
                                      _showErrorSnack(ctx, "Failed: $e");
                                    }
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
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

  // ── Edit Variant NON-default (variant saja) ───────────────
  void _showEditVariant(BuildContext context, int productId, Map variant) {
    final stockCtrl =
        TextEditingController(text: variant['stock']?.toString() ?? '0');
    final sellCtrl =
        TextEditingController(text: variant['sell_price']?.toString() ?? '0');
    final buyCtrl =
        TextEditingController(text: variant['buy_price']?.toString() ?? '0');
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
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 36,
                      height: 4,
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
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
                                    final newStock =
                                        double.tryParse(stockCtrl.text) ?? 0;
                                    final newSell =
                                        double.tryParse(sellCtrl.text) ?? 0;
                                    final newBuy =
                                        double.tryParse(buyCtrl.text) ?? 0;

                                    await SupabaseService
                                        .updateProductVariant(
                                      variantId: variantId,
                                      stock: newStock,
                                      sellPrice: newSell,
                                      buyPrice: newBuy,
                                    );

                                    setState(() {
                                      variant['stock'] = newStock;
                                      variant['sell_price'] = newSell;
                                      variant['buy_price'] = newBuy;
                                    });

                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      _showSavedSnack(
                                          context, "Variant updated");
                                    }
                                  } catch (e) {
                                    setModal(() => saving = false);
                                    if (ctx.mounted) {
                                      _showErrorSnack(ctx, "Failed: $e");
                                    }
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
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

  // ── Add Variant Modal (dipertahankan + conversion factor) ─
  void _showAddVariant(BuildContext context, Map product) {
    final productId = product['id'] as int;
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final factorCtrl = TextEditingController(text: '1');
    final stockCtrl = TextEditingController(text: '0');
    final sellCtrl = TextEditingController(text: '0');
    final buyCtrl = TextEditingController(text: '0');
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        width: 36,
                        height: 4,
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
                      Expanded(
                        child: Text(product['name'] ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                      ),
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
                      _textField(
                        label: "Variant name",
                        controller: nameCtrl,
                        icon: Icons.label_rounded,
                        iconColor: const Color(0xFF6C63FF),
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        label: "Unit (e.g. kg, pcs, box)",
                        controller: unitCtrl,
                        icon: Icons.straighten_rounded,
                        iconColor: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 12),
                      // Conversion factor: berapa unit dasar (kg) per
                      // 1 variant ini. Contoh: cup 500 gr = 0.5
                      _editField(
                        label:
                            "Conversion factor (kg per 1 pcs, e.g. 0.5)",
                        controller: factorCtrl,
                        icon: Icons.swap_horiz_rounded,
                        iconColor: const Color(0xFF8B5CF6),
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: saving
                              ? null
                              : () async {
                                  final name = nameCtrl.text.trim();
                                  if (name.isEmpty) {
                                    _showErrorSnack(
                                        ctx, "Variant name is required");
                                    return;
                                  }
                                  if (name.toLowerCase() == 'default') {
                                    _showErrorSnack(ctx,
                                        '"default" is reserved, use another name');
                                    return;
                                  }
                                  final factor =
                                      double.tryParse(factorCtrl.text) ?? 0;
                                  if (factor <= 0) {
                                    _showErrorSnack(ctx,
                                        "Conversion factor must be > 0");
                                    return;
                                  }
                                  setModal(() => saving = true);
                                  try {
                                    final newVariant = await SupabaseService
                                        .insertProductVariant(
                                      productId: productId,
                                      name: name,
                                      unit: unitCtrl.text.trim(),
                                      stock: double.tryParse(
                                              stockCtrl.text) ??
                                          0,
                                      sellPrice: double.tryParse(
                                              sellCtrl.text) ??
                                          0,
                                      buyPrice:
                                          double.tryParse(buyCtrl.text) ??
                                              0,
                                      conversionFactor: factor,
                                    );
                                    setState(() {
                                      (product['product_variants']
                                              as List?)
                                          ?.add(newVariant);
                                      product['product_variants'] ??= [
                                        newVariant
                                      ];
                                    });
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      _showSavedSnack(
                                          context, "Variant added");
                                    }
                                  } catch (e) {
                                    setModal(() => saving = false);
                                    if (ctx.mounted) {
                                      _showErrorSnack(ctx, "Failed: $e");
                                    }
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
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
      ),
    );
  }

  // ── Shared field widgets ──────────────────────────────────
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
          width: 44,
          height: 48,
          decoration: const BoxDecoration(
            border:
                Border(right: BorderSide(color: Color(0xFF222840), width: 1)),
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
              hintStyle:
                  const TextStyle(color: Color(0xFF4A5568), fontSize: 13),
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
          width: 44,
          height: 48,
          decoration: const BoxDecoration(
            border:
                Border(right: BorderSide(color: Color(0xFF222840), width: 1)),
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
              hintStyle:
                  const TextStyle(color: Color(0xFF4A5568), fontSize: 13),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showErrorSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF2D0A0A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    width: 40,
                    height: 40,
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
                // Tombol "+" → halaman Create Product
                GestureDetector(
                  onTap: () async {
                    final created = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CreateProductPage()),
                    );
                    // refresh kalau ada product baru
                    if (created == true) _loadProducts();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
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
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Color(0xFF6C63FF)),
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
                                      color: Color(0xFF4A5568),
                                      fontSize: 15)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: const Color(0xFF6C63FF),
                          backgroundColor: const Color(0xFF161B27),
                          onRefresh: _loadProducts,
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) =>
                                _buildProductCard(context, filtered[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Product Card (variant selalu tampil) ──────────────────
  Widget _buildProductCard(BuildContext context, Map p) {
    final variants = _variantsOf(p);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF222840), width: 1),
      ),
      child: Column(
        children: [
          // Main row — tap = edit product + default variant (sinkron)
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              splashColor: const Color(0xFF6C63FF).withOpacity(0.08),
              onTap: () => _showEditSynced(context, p),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.inventory_2_rounded,
                        color: Color(0xFF6C63FF), size: 24),
                  ),
                  const SizedBox(width: 14),
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
                        const SizedBox(height: 3),
                        Text(
                          "${variants.length} variant${variants.length != 1 ? 's' : ''}",
                          style: const TextStyle(
                              color: Color(0xFF4A5568), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Kanan: hanya sell price (stock & buy price
                  // level product dihilangkan dari tampilan)
                  Text(
                    "Rp ${_formatPrice(p['sell_price'])}",
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // Variants — selalu tampil, tanpa expand
          const Divider(
              color: Color(0xFF222840), height: 1, indent: 16, endIndent: 16),
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
                GestureDetector(
                  onTap: () => _showAddVariant(context, p),
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
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
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
              ],
            ),
          ),
          if (variants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text("No variants",
                  style:
                      TextStyle(color: Color(0xFF4A5568), fontSize: 12)),
            )
          else
            ...variants.map((v) => _buildVariantRow(context, p, v)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildVariantRow(BuildContext context, Map product, Map v) {
    final stockColor = _stockColor(v['stock'] ?? 0);
    final isActive = v['is_active'] == true;
    final isDefault = v['name'] == 'default';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // variant 'default' → edit sinkron (product + default),
        // variant lain → edit variant saja
        onTap: () => isDefault
            ? _showEditSynced(context, product)
            : _showEditVariant(context, product['id'] as int, v),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(children: [
            Container(
              width: 2,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? (isDefault
                        ? const Color(0xFF10B981).withOpacity(0.5)
                        : const Color(0xFF6C63FF).withOpacity(0.35))
                    : const Color(0xFF2A3040),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDefault
                    ? const Color(0xFF062318)
                    : const Color(0xFF1A1830),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                  isDefault ? Icons.star_rounded : Icons.tune_rounded,
                  color: !isActive
                      ? const Color(0xFF2A3040)
                      : isDefault
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6C63FF),
                  size: 15),
            ),
            const SizedBox(width: 10),
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
                    if (!isDefault) ...[
                      const SizedBox(width: 6),
                      Text(
                        "×${_formatFactor(v['conversion_factor'])} kg",
                        style: const TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
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
                      width: 5,
                      height: 5,
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