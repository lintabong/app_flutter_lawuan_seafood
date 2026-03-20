import 'package:flutter/material.dart';
import '../../helpers/currency_utils.dart';
import '../../helpers/date_utils.dart' as AppDateUtils;
import '../../helpers/status_utils.dart';
import '../../helpers/text_utils.dart';
import '../../constants.dart';
import 'order_expanded_section.dart';
import 'status_picker_sheet.dart';

class OrderCard extends StatelessWidget {
  final Map order;
  final bool isSelected;
  final bool isUpdating;
  final Set<int> updatingItems;
  final List<String> statuses;
  final bool Function(String from, String to) requiresRpc;
  final VoidCallback onTap;
  final void Function(String newStatus) onStatusChanged;
  final VoidCallback onCopyInvoice;
  final void Function(int ii) onToggleItem;

  const OrderCard({
    super.key,
    required this.order,
    required this.isSelected,
    required this.isUpdating,
    required this.updatingItems,
    required this.statuses,
    required this.requiresRpc,
    required this.onTap,
    required this.onStatusChanged,
    required this.onCopyInvoice,
    required this.onToggleItem,
  });

  static const Color _cyan   = AppColors.cyan;
  static const Color _cyanBg = AppColors.cyanBg;
  static const Color _amber  = AppColors.amber;

  void _showStatusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatusPickerSheet(
        currentStatus: order['status'] as String,
        statuses: statuses,
        requiresRpc: requiresRpc,
        onSelect: onStatusChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderId    = order['id'] as int;
    final orderDate  = DateTime.tryParse(order['order_date']?.toString() ?? '');
    final orderLocal = orderDate?.toLocal();

    final orderDateLabel = orderLocal != null
        ? AppDateUtils.DateUtils.formatFullDate(orderLocal)
        : '—';
    final orderTimeLabel = orderLocal != null
        ? "${orderLocal.hour.toString().padLeft(2, '0')}:${orderLocal.minute.toString().padLeft(2, '0')}"
        : '--:--';

    final customer = order['customers'] as Map? ?? {};
    final items    = (order['order_items'] as List?) ?? [];
    final st       = StatusUtils.statusStyle(order['status']);
    final statusColor = st['color'] as Color;
    final hasCoords   = double.tryParse(customer['latitude']?.toString() ?? '') != null;
    final total    = double.tryParse(order['total_amount']?.toString()   ?? '0') ?? 0;
    final delivery = double.tryParse(order['delivery_price']?.toString() ?? '0') ?? 0;
    final subtotal = total - delivery;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Color(0xFF161B27),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _cyan.withOpacity(0.5) : Color(0xFF222840),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(
                  color: _cyan.withOpacity(0.1),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                )]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected ? _cyanBg : Color(0xFF0F1117),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delivery_dining_rounded,
                      color: isSelected ? _cyan : Color(0xFF4A5568),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),

                  // Main info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(
                            '#$orderId',
                            style: TextStyle(
                              color: _amber,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 6),
                          if (hasCoords)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _cyanBg,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_rounded,
                                      size: 9, color: _cyan),
                                  SizedBox(width: 3),
                                  Text(
                                    'On map',
                                    style: TextStyle(
                                      color: _cyan,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ]),
                        SizedBox(height: 3),
                        Text(
                          customer['name'] ?? 'Unknown',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.access_time_rounded,
                              size: 11, color: Color(0xFF4A5568)),
                          SizedBox(width: 4),
                          Text(
                            "$orderDateLabel · $orderTimeLabel",
                            style: TextStyle(
                              color: Color(0xFF4A5568),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ]),
                        SizedBox(height: 2),
                        Text(
                          customer['address'] ?? customer['phone'] ?? '—',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Rp ${CurrencyUtils.formatPrice(total)}',
                          style: TextStyle(
                            color: _amber,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 8),

                  // Right column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status badge
                      GestureDetector(
                        onTap: () => _showStatusPicker(context),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: st['bg'],
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: statusColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: isUpdating
                              ? SizedBox(
                                  width: 58,
                                  height: 14,
                                  child: Center(
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(st['icon'],
                                        size: 11, color: statusColor),
                                    SizedBox(width: 4),
                                    Text(
                                      TextUtils.capitalize(
                                          order['status'] ?? ''),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Icon(
                                      Icons.expand_more_rounded,
                                      size: 12,
                                      color: statusColor.withOpacity(0.7),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: 6),

                      // Invoice copy button
                      GestureDetector(
                        onTap: onCopyInvoice,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF1A2035),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: Color(0xFF2A3040),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  size: 11, color: Color(0xFF94A3B8)),
                              SizedBox(width: 4),
                              Text(
                                'Invoice',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 6),

                      // Expand arrow
                      AnimatedRotation(
                        turns: isSelected ? 0.5 : 0,
                        duration: Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF4A5568),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Expanded section
            AnimatedCrossFade(
              firstChild: SizedBox.shrink(),
              secondChild: OrderExpandedSection(
                items: items,
                subtotal: subtotal,
                delivery: delivery,
                total: total,
                updatingItems: updatingItems,
                onToggleItem: onToggleItem,
              ),
              crossFadeState: isSelected
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}
