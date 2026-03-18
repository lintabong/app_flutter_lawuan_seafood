import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'customer_form_page.dart';

class CustomerPage extends StatefulWidget {
  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  List customers = [];
  List filtered = [];
  bool loading = true;
  final TextEditingController _searchController = TextEditingController();

  Future loadCustomers() async {
    final data = await SupabaseService.getCustomers();
    setState(() {
      customers = data;
      filtered = data;
      loading = false;
    });
  }

  void _onSearch(String query) {
    setState(() {
      filtered = query.isEmpty
          ? customers
          : customers.where((c) {
              final name = c['name'].toString().toLowerCase();
              final phone = (c['phone'] ?? '').toString().toLowerCase();
              final address = (c['address'] ?? '').toString().toLowerCase();
              final q = query.toLowerCase();
              return name.contains(q) || phone.contains(q) || address.contains(q);
            }).toList();
    });
  }

  Future _openForm({Map<String, dynamic>? customer}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerFormPage(customer: customer),
      ),
    );
    if (result == true) {
      setState(() => loading = true);
      _searchController.clear();
      loadCustomers();
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

  @override
  void initState() {
    super.initState();
    loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                          "Customers",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (!loading)
                          Text(
                            "${filtered.length} customers",
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openForm(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFF1E1B4B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFF6C63FF).withOpacity(0.3), width: 1),
                      ),
                      child: Icon(Icons.add_rounded, color: Color(0xFF6C63FF), size: 22),
                    ),
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
                    hintText: "Search by name, phone, address...",
                    hintStyle: TextStyle(color: Color(0xFF4A5568), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF4A5568), size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                            child: Icon(Icons.close_rounded, color: Color(0xFF4A5568), size: 18),
                          )
                        : null,
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
                            "Loading customers...",
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
                              Icon(Icons.people_outline_rounded, color: Color(0xFF2A3040), size: 64),
                              SizedBox(height: 16),
                              Text(
                                "No customers found",
                                style: TextStyle(color: Color(0xFF4A5568), fontSize: 15),
                              ),
                              if (_searchController.text.isNotEmpty) ...[
                                SizedBox(height: 8),
                                Text(
                                  'Try a different search term',
                                  style: TextStyle(color: Color(0xFF2A3040), fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final c = filtered[index];
                            final avatarColor = _avatarColor(c['name'] ?? '');
                            final hasLocation = c['latitude'] != null && c['longitude'] != null;

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
                                  onTap: () => _openForm(customer: Map<String, dynamic>.from(c)),
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: avatarColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: avatarColor.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _initials(c['name'] ?? '?'),
                                              style: TextStyle(
                                                color: avatarColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 14),

                                        // Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c['name'] ?? '-',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                              SizedBox(height: 5),
                                              if (c['phone'] != null && c['phone'].toString().isNotEmpty)
                                                Row(
                                                  children: [
                                                    Icon(Icons.phone_rounded, color: Color(0xFF4A5568), size: 12),
                                                    SizedBox(width: 5),
                                                    Text(
                                                      c['phone'],
                                                      style: TextStyle(
                                                        color: Color(0xFF64748B),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              if (c['address'] != null && c['address'].toString().isNotEmpty) ...[
                                                SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Icon(Icons.location_on_rounded, color: Color(0xFF4A5568), size: 12),
                                                    SizedBox(width: 5),
                                                    Expanded(
                                                      child: Text(
                                                        c['address'],
                                                        style: TextStyle(
                                                          color: Color(0xFF4A5568),
                                                          fontSize: 11,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        // Right side
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            if (hasLocation)
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Color(0xFF10B981).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.gps_fixed_rounded, color: Color(0xFF10B981), size: 10),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      "GPS",
                                                      style: TextStyle(
                                                        color: Color(0xFF10B981),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            SizedBox(height: hasLocation ? 8 : 0),
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