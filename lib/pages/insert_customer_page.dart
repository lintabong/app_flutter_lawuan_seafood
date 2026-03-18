import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class InsertCustomerPage extends StatefulWidget {
  @override
  State<InsertCustomerPage> createState() => _InsertCustomerPageState();
}

class _InsertCustomerPageState extends State<InsertCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  bool _saving = false;
  String? _errorMsg;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    try {
      await supabase.from('customers').insert({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'latitude': _latController.text.trim().isEmpty ? null : double.tryParse(_latController.text.trim()),
        'longitude': _lngController.text.trim().isEmpty ? null : double.tryParse(_lngController.text.trim()),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMsg = "Failed to save customer. Please try again.";
        _saving = false;
      });
    }
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
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
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

  @override
  Widget build(BuildContext context) {
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
                          "New Customer",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          "Fill in the customer details",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ],
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
                      // Avatar preview
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Color(0xFF1E1B4B),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Color(0xFF6C63FF).withOpacity(0.3), width: 1.5),
                          ),
                          child: Icon(Icons.person_add_rounded, color: Color(0xFF6C63FF), size: 32),
                        ),
                      ),

                      SizedBox(height: 28),

                      // Section: Basic Info
                      _sectionLabel("Basic Information"),
                      SizedBox(height: 14),

                      _buildField(
                        label: "FULL NAME",
                        hint: "e.g. John Doe",
                        icon: Icons.person_rounded,
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

                      // Section: Address
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

                      // Section: Location
                      _sectionLabel("GPS Coordinates"),
                      SizedBox(height: 6),
                      Text(
                        "Optional — used for map features",
                        style: TextStyle(color: Color(0xFF2A3040), fontSize: 12),
                      ),
                      SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              label: "LATITUDE",
                              hint: "-6.966667",
                              icon: Icons.explore_rounded,
                              controller: _latController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final val = double.tryParse(v.trim());
                                if (val == null) return 'Invalid number';
                                if (val < -90 || val > 90) return 'Must be -90 to 90';
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildField(
                              label: "LONGITUDE",
                              hint: "110.416664",
                              icon: Icons.explore_outlined,
                              controller: _lngController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final val = double.tryParse(v.trim());
                                if (val == null) return 'Invalid number';
                                if (val < -180 || val > 180) return 'Must be -180 to 180';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 28),

                      // Error message
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
                                child: Text(
                                  _errorMsg!,
                                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6C63FF),
                            disabledBackgroundColor: Color(0xFF6C63FF).withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _saving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      "Save Customer",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
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

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: Color(0xFF6C63FF), borderRadius: BorderRadius.circular(2))),
        SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}