
// ═══════════════════════════════════════════════════════════════════
// lib/pages/create_product_page.dart  (file BARU)
//
// Membuat product baru sekaligus variant 'default'-nya lewat RPC
// insert_product_with_default_variant (sudah ada di database kamu).
// Category ID diisi angka manual sesuai permintaan.
//
// Setelah sukses, halaman pop dengan result `true` — ProductPage
// menggunakan nilai ini untuk refresh list.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class CreateProductPage extends StatefulWidget {
  @override
  State<CreateProductPage> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends State<CreateProductPage> {
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'kg');
  final _buyCtrl = TextEditingController(text: '0');
  final _sellCtrl = TextEditingController(text: '0');
  final _stockCtrl = TextEditingController(text: '0');

  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _unitCtrl.dispose();
    _buyCtrl.dispose();
    _sellCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Product name is required');
      return;
    }

    final categoryId = int.tryParse(_categoryCtrl.text.trim());
    if (categoryId == null) {
      _snack('Category ID must be a number');
      return;
    }

    setState(() => _submitting = true);
    try {
      final newId = await SupabaseService.insertProductWithDefaultVariant(
        name: name,
        categoryId: categoryId,
        unit: _unitCtrl.text.trim(),
        buyPrice: double.tryParse(_buyCtrl.text) ?? 0,
        sellPrice: double.tryParse(_sellCtrl.text) ?? 0,
        stock: double.tryParse(_stockCtrl.text) ?? 0,
      );

      if (mounted) {
        _snack('Product #$newId created ✓', success: true);
        Navigator.pop(context, true); // true → ProductPage refresh
      }
    } catch (e) {
      _snack('Error: ${e.toString()}');
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _sectionLabel('PRODUCT INFO'),
                    _textField(
                      label: "Product name (e.g. Ikan Patin)",
                      controller: _nameCtrl,
                      icon: Icons.inventory_2_rounded,
                      iconColor: const Color(0xFF6C63FF),
                    ),
                    const SizedBox(height: 12),
                    _numberField(
                      label: "Category ID",
                      controller: _categoryCtrl,
                      icon: Icons.category_rounded,
                      iconColor: const Color(0xFF06B6D4),
                      integerOnly: true,
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      label: "Unit (default: kg)",
                      controller: _unitCtrl,
                      icon: Icons.straighten_rounded,
                      iconColor: const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 24),
                    _sectionLabel('PRICES & STOCK'),
                    _numberField(
                      label: "Buy Price",
                      controller: _buyCtrl,
                      prefix: "Rp",
                      icon: Icons.shopping_bag_rounded,
                      iconColor: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 12),
                    _numberField(
                      label: "Sell Price",
                      controller: _sellCtrl,
                      prefix: "Rp",
                      icon: Icons.sell_rounded,
                      iconColor: const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 12),
                    _numberField(
                      label: "Initial Stock",
                      controller: _stockCtrl,
                      icon: Icons.inventory_rounded,
                      iconColor: const Color(0xFF6C63FF),
                    ),
                    const SizedBox(height: 16),

                    // Info: variant default dibuat otomatis
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF062318),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                const Color(0xFF10B981).withOpacity(0.25),
                            width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Variant "default" akan dibuat otomatis '
                              'dengan stock & harga yang sama',
                              style: TextStyle(
                                color: const Color(0xFF10B981)
                                    .withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildSubmitButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

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
                  "New Product",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "Create product with default variant",
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

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
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

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    String prefix = '',
    bool integerOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
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
            keyboardType: integerOnly
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              integerOnly
                  ? FilteringTextInputFormatter.digitsOnly
                  : FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
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
        const SizedBox(width: 12),
      ]),
    );
  }

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
                    'Create Product',
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