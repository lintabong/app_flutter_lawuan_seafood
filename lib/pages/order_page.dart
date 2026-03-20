
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../helpers/text_utils.dart';
import '../constants.dart';
import 'widgets/order_card.dart';
import 'widgets/order_filter_bar.dart';

class OrderPage extends StatefulWidget {
  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  List orders = [];
  bool loading = true;

  // Filters
  DateTime? selectedDate;
  String? selectedStatus;
  String _nameQuery = '';
  final TextEditingController _nameController = TextEditingController();

  // Pagination
  int _page = 1;
  static const int _pageSize = 10;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  int? selectedOrderIndex;
  final Set<int> _updatingItems  = {};
  final Set<int> _updatingOrders = {};

  static const Color _cyan = AppColors.cyan;

  static const List<String> _statuses = [
    'pending', 'prepared', 'paid', 'delivered', 'picked up', 'cancelled',
  ];

  bool _requiresRpc(String from, String to) {
    const triggers = {'pending', 'prepared'};
    const targets  = {'paid', 'delivered', 'picked up'};
    return triggers.contains(from) && targets.contains(to);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future _load() async {
    setState(() {
      loading = true;
      selectedOrderIndex = null;
      _page = 1;
      _hasMore = true;
      orders = [];
    });
    final data = await SupabaseService.getOrders(
      page: 1,
      pageSize: _pageSize,
      date: selectedDate,
      status: selectedStatus,
      name: _nameQuery.isNotEmpty ? _nameQuery : null,
      withItems: true,
    );
    setState(() {
      orders = data;
      loading = false;
      _hasMore = data.length == _pageSize;
    });
  }

  Future _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final data = await SupabaseService.getOrders(
      page:      nextPage,
      pageSize:  _pageSize,
      date:      selectedDate,
      status:    selectedStatus,
      name:      _nameQuery.isNotEmpty ? _nameQuery : null,
      withItems: true,
    );
    setState(() {
      _page        = nextPage;
      _loadingMore = false;
      _hasMore     = data.length == _pageSize;
      orders.addAll(data);
    });
  }

  Future _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: _cyan,
            surface: Color(0xFF161B27),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: Color(0xFF161B27),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      _load();
    }
  }

  Future _toggleItem(int oi, int ii) async {
    final item    = orders[oi]['order_items'][ii];
    final itemId  = item['id'] as int;
    final current = item['is_prepared'] == true;
    if (_updatingItems.contains(itemId)) return;
    setState(() => _updatingItems.add(itemId));
    try {
      await SupabaseService.toggleItemPrepared(itemId, !current);
      setState(() => orders[oi]['order_items'][ii]['is_prepared'] = !current);
    } finally {
      setState(() => _updatingItems.remove(itemId));
    }
  }

  Future _changeStatus(int oi, String newStatus) async {
    final order     = orders[oi];
    final orderId   = order['id'] as int;
    final oldStatus = order['status'] as String;
    if (oldStatus == newStatus || _updatingOrders.contains(orderId)) return;
    setState(() => _updatingOrders.add(orderId));
    try {
      await SupabaseService.updateOrderStatusRpc(
          orderId: orderId, newStatus: newStatus);
      setState(() => orders[oi]['status'] = newStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: const Color(0xFF2D0A0A),
        ));
      }
    } finally {
      setState(() => _updatingOrders.remove(orderId));
    }
  }

  Future<void> _copyInvoice(Map order) async {
    final text =
        TextUtils.buildFullInvoiceText(Map<String, dynamic>.from(order));
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_rounded,
              color: Color(0xFF10B981), size: 16),
          SizedBox(width: 10),
          Text('Invoice copied!', style: TextStyle(fontSize: 13)),
        ]),
        backgroundColor: Color(0xFF1E2333),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F1117),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          OrderFilterBar(
            nameController: _nameController,
            nameQuery:      _nameQuery,
            selectedDate:   selectedDate,
            selectedStatus: selectedStatus,
            statuses:       _statuses,
            onPickDate:     () => _pickDate(context),
            onNameChanged: (v) {
              _nameQuery = v;
              Future.delayed(Duration(milliseconds: 400), () {
                if (_nameQuery == v) _load();
              });
            },
            onNameCleared: () {
              _nameController.clear();
              _nameQuery = '';
              _load();
            },
            onStatusChanged: (s) {
              setState(() => selectedStatus = s);
              _load();
            },
            onDateCleared: () {
              setState(() => selectedDate = null);
              _load();
            },
          ),
          Expanded(
            child: loading
                ? Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: _cyan),
                    ),
                  )
                : orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delivery_dining_outlined,
                                color: Color(0xFF2A3040), size: 52),
                            SizedBox(height: 12),
                            Text(
                              'No orders found',
                              style: TextStyle(
                                  color: Color(0xFF4A5568), fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: orders.length + (_hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == orders.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _cyan),
                                ),
                              ),
                            );
                          }
                          return _buildCard(i);
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(children: [
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
            child: Icon(Icons.arrow_back_rounded,
                color: Color(0xFF94A3B8), size: 20),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Orders',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              if (!loading)
                Text(
                  '${orders.length} orders',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildCard(int oi) {
    final o       = orders[oi];
    final orderId = o['id'] as int;
    return OrderCard(
      order:        o,
      isSelected:   selectedOrderIndex == oi,
      isUpdating:   _updatingOrders.contains(orderId),
      updatingItems: _updatingItems,
      statuses:     _statuses,
      requiresRpc:  _requiresRpc,
      onTap: () {
        setState(() =>
            selectedOrderIndex = selectedOrderIndex == oi ? null : oi);
      },
      onStatusChanged: (newStatus) => _changeStatus(oi, newStatus),
      onCopyInvoice:   () => _copyInvoice(o),
      onToggleItem:    (ii) => _toggleItem(oi, ii),
    );
  }
}
