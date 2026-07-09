import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class SupplierFormPage extends StatefulWidget {
  final Map<String, dynamic>? supplier; // null = insert, non-null = update

  const SupplierFormPage({Key? key, this.supplier}) : super(key: key);

  bool get isEditing => supplier != null;

  @override
  State<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends State<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _saving = false;
  bool _deleting = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final s = widget.supplier!;
      _nameController.text = s['name'] ?? '';
      _phoneController.text = s['phone'] ?? '';
      _addressController.text = s['address'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    final data = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
    };

    try {
      if (widget.isEditing) {
        await SupabaseService.updateSupplier(widget.supplier!['id'], data);
      } else {
        await SupabaseService.insertSupplier(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMsg = widget.isEditing
            ? "Failed to update supplier. Please try again."
            : "Failed to save supplier. Please try again.";
        _saving = false;
      });
    }
  }

  Future _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF161B27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete Supplier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete this supplier? It will be hidden from lists but existing transactions stay intact.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      _deleting = true;
      _errorMsg = null;
    });

    try {
      await SupabaseService.deleteSupplier(widget.supplier!['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMsg = "Failed to delete supplier. Please try again.";
        _deleting = false;
      });
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _avatarColor(String name) {
    final colors = [
      Color(0xFF6C63FF), Color(0xFF10B981), Color(0xFFF59E0B),
      Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFFEC4899),
      Color(0xFF8B5CF6), Color(0xFF14B8A6),
    ];
    int hash = name.codeUnits.fold(0, (prev, e) => prev + e);
    return colors[hash % colors.length];
  }

  Widget _buildField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFF161B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFF222840), width: 1),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Color(0xFF2A3040), fontSize: 14),
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, color: Color(0xFF4A5568), size: 18),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              errorStyle: TextStyle(color: Color(0xFFEF4444), fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(color: Color(0xFF6C63FF), borderRadius: BorderRadius.circular(2)),
        ),
        SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;
    final avatarColor = isEditing ? _avatarColor(widget.supplier!['name'] ?? '') : Color(0xFF6C63FF);
    final busy = _saving || _deleting;

    return Scaffold(
      backgroundColor: Color(0xFF0F1117),
      body: SafeArea(
        child: Column(
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
                          isEditing ? "Edit Supplier" : "New Supplier",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        Text(
                          isEditing ? "Update the supplier details" : "Fill in the supplier details",
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (isEditing)
                    GestureDetector(
                      onTap: busy ? null : _delete,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(0xFFEF4444).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFFEF4444).withOpacity(0.3), width: 1),
                        ),
                        child: _deleting
                            ? Padding(
                                padding: EdgeInsets.all(11),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                              )
                            : Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: avatarColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: avatarColor.withOpacity(0.35), width: 1.5),
                          ),
                          child: isEditing
                              ? Center(
                                  child: Text(
                                    _initials(widget.supplier!['name'] ?? '?'),
                                    style: TextStyle(color: avatarColor, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                                  ),
                                )
                              : Icon(Icons.add_business_rounded, color: Color(0xFF6C63FF), size: 32),
                        ),
                      ),

                      if (isEditing) ...[
                        SizedBox(height: 12),
                        Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Color(0xFF1E2333),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Color(0xFF2A3040), width: 1),
                            ),
                            child: Text(
                              "ID #${widget.supplier!['id']}",
                              style: TextStyle(color: Color(0xFF4A5568), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ],

                      SizedBox(height: 28),

                      _sectionLabel("Basic Information"),
                      SizedBox(height: 14),

                      _buildField(
                        label: "SUPPLIER NAME",
                        hint: "e.g. PT Sumber Pangan",
                        icon: Icons.store_rounded,
                        controller: _nameController,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Name is required';
                          if (v.trim().length < 2) return 'Name too short';
                          return null;
                        },
                      ),

                      SizedBox(height: 16),

                      _buildField(
                        label: "PHONE NUMBER",
                        hint: "e.g. +62 812 3456 7890",
                        icon: Icons.phone_rounded,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),

                      SizedBox(height: 28),

                      _sectionLabel("Address"),
                      SizedBox(height: 14),

                      _buildField(
                        label: "FULL ADDRESS",
                        hint: "Street, city, province...",
                        icon: Icons.home_rounded,
                        controller: _addressController,
                        maxLines: 3,
                      ),

                      SizedBox(height: 28),

                      if (_errorMsg != null)
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 16),
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFFEF4444).withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(_errorMsg!, style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                              ),
                            ],
                          ),
                        ),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: busy ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEditing ? Color(0xFFF59E0B) : Color(0xFF6C63FF),
                            disabledBackgroundColor: (isEditing ? Color(0xFFF59E0B) : Color(0xFF6C63FF)).withOpacity(0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _saving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(isEditing ? Icons.save_rounded : Icons.check_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      isEditing ? "Update Supplier" : "Save Supplier",
                                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}