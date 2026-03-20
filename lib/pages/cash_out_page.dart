import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class CashOutPage extends StatefulWidget {
  @override
  State<CashOutPage> createState() => _CashOutPageState();
}

class _CashOutPageState extends State<CashOutPage> {
  // ── Form State ────────────────────────────────────────────
  DateTime _transactionDate = DateTime.now();
  String _status = 'draft';
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  bool _submitting = false;

  // ── Expense categories (customize as needed) ───────────────
  final List<String> _categories = [
    'Salaries & Wages',
    'Driver Payments',
    'Equipment',
    'Rent',
    'Utilities',
    'Other Expenses'
  ];
  String? _selectedCategory;

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────
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

  double get _parsedAmount =>
      double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;

  // ── Date Picker ───────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => _pickerTheme(child),
    );
    if (picked == null) return;
    setState(() {
      _transactionDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _transactionDate.hour,
        _transactionDate.minute,
      );
    });
  }

  Widget _pickerTheme(Widget? child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFEF4444),
            onPrimary: Colors.white,
            surface: Color(0xFF1E2333),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF161B27),
          textButtonTheme: TextButtonThemeData(
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
          ),
        ),
        child: child!,
      );

  // ── Category Sheet ─────────────────────────────────────────
  void _openCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryPickerSheet(
        categories: _categories,
        selected: _selectedCategory,
        onSelect: (c) => setState(() => _selectedCategory = c),
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedCategory == null) {
      _snack('Please select a category');
      return;
    }
    if (_parsedAmount <= 0) {
      _snack('Amount must be greater than zero');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await SupabaseService.expenseTransaction(
        categoryName: _selectedCategory!,
        amount: _parsedAmount,
        description: _descController.text.trim(),
        status: _status,
        transactionDate: _transactionDate,
      );

      if (mounted) {
        _snack('Expense #${result['transaction_id']} saved ✓', success: true);
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
                          _buildDateSection(),
                          const SizedBox(height: 20),
                          _buildCategorySection(),
                          const SizedBox(height: 20),
                          _buildAmountSection(),
                          const SizedBox(height: 20),
                          _buildStatusSection(),
                          const SizedBox(height: 20),
                          _buildDescriptionSection(),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cash Out',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'New expense transaction',
                style: TextStyle(color: const Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          // Red accent dot
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Label ──────────────────────────────────────────
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
        _sectionLabel('TRANSACTION DATE'),
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
                        _formatDate(_transactionDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _formatUtcLabel(_transactionDate),
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

  // ── Category ───────────────────────────────────────────────
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('CATEGORY'),
        GestureDetector(
          onTap: _openCategorySheet,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedCategory != null
                    ? const Color(0xFFF59E0B).withOpacity(0.35)
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
                    color: const Color(0xFF2D2410),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.category_rounded,
                      color: Color(0xFFF59E0B), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedCategory ?? 'Select category...',
                    style: TextStyle(
                      color: _selectedCategory != null
                          ? Colors.white
                          : const Color(0xFF4A5568),
                      fontSize: _selectedCategory != null ? 15 : 14,
                      fontWeight: _selectedCategory != null
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
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

  // ── Amount ─────────────────────────────────────────────────
  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('AMOUNT'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _parsedAmount > 0
                  ? const Color(0xFFEF4444).withOpacity(0.4)
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
                  color: const Color(0xFF2D1B1B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_down_rounded,
                    color: Color(0xFFEF4444), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Rp ',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle:
                        TextStyle(color: Color(0xFF2A3040), fontSize: 18),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
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
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
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
              hintText: 'Optional notes about this expense...',
              hintStyle: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
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

  // ── Submit Button ──────────────────────────────────────────
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
                  ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
                  : [const Color(0xFF7C3AED), const Color(0xFF6C63FF)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isPosted
                        ? const Color(0xFFEF4444)
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
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPosted
                            ? Icons.send_rounded
                            : Icons.save_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isPosted ? 'Post Expense' : 'Save as Draft',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Category Picker Sheet
// ═══════════════════════════════════════════════════════════════════════════════
class _CategoryPickerSheet extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final void Function(String) onSelect;

  const _CategoryPickerSheet({
    required this.categories,
    required this.onSelect,
    this.selected,
  });

  IconData _iconFor(String cat) {
    switch (cat) {
      case 'Salaries & Wages':
        return Icons.people_rounded;
      case 'Utilities':
        return Icons.bolt_rounded;
      case 'Rent':
        return Icons.home_rounded;
      case 'Other Expenses':
        return Icons.business_center_rounded;
      case 'Equipment':
        return Icons.campaign_rounded;
      case 'Maintenance':
        return Icons.build_rounded;
      case 'Driver Payments':
        return Icons.directions_car_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
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
              padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Category',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: categories.length,
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final isSelected = selected == cat;
                  return GestureDetector(
                    onTap: () {
                      onSelect(cat);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2D2410)
                            : const Color(0xFF0F1117),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFF59E0B).withOpacity(0.5)
                              : const Color(0xFF222840),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFF59E0B).withOpacity(0.15)
                                  : const Color(0xFF1E2333),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_iconFor(cat),
                                color: isSelected
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF4A5568),
                                size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              cat,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFFF59E0B), size: 20)
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