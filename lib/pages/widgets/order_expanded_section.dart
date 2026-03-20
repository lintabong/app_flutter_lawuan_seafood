import 'package:flutter/material.dart';
import '../../helpers/currency_utils.dart';
import '../../constants.dart';
import 'order_item_row.dart';

class OrderExpandedSection extends StatelessWidget {
  final List items;
  final double subtotal;
  final double delivery;
  final double total;
  final Set<int> updatingItems;
  final void Function(int ii) onToggleItem;

  const OrderExpandedSection({
    super.key,
    required this.items,
    required this.subtotal,
    required this.delivery,
    required this.total,
    required this.updatingItems,
    required this.onToggleItem,
  });

  static const Color _cyan  = AppColors.cyan;
  static const Color _amber = AppColors.amber;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Divider(color: Color(0xFF222840), height: 1, indent: 14, endIndent: 14),

      if (items.isNotEmpty) ...[
        Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ITEMS",
                style: TextStyle(
                  color: Color(0xFF4A5568),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                "${items.where((i) => i['is_prepared'] == true).length}/${items.length} prepared",
                style: TextStyle(
                  color: items.every((i) => i['is_prepared'] == true)
                      ? Color(0xFF10B981)
                      : Color(0xFF4A5568),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...List.generate(items.length, (ii) {
          final item   = items[ii];
          final itemId = item['id'] as int;
          return OrderItemRow(
            item: item,
            isLoading: updatingItems.contains(itemId),
            onTap: () => onToggleItem(ii),
          );
        }),
      ],

      // Totals summary
      Container(
        margin: EdgeInsets.fromLTRB(14, 4, 14, 14),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF0F1117),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF222840), width: 1),
        ),
        child: Column(children: [
          _totalRow('Subtotal', subtotal, Color(0xFFCBD5E1)),
          SizedBox(height: 8),
          _totalRow('Delivery fee', delivery, _cyan),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFF222840), height: 1),
          ),
          _totalRow('Total', total, _amber, large: true),
        ]),
      ),
    ]);
  }

  Widget _totalRow(String label, double amount, Color valueColor,
      {bool large = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: large ? Colors.white : Color(0xFF64748B),
            fontSize: large ? 14 : 12,
            fontWeight: large ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        Text(
          'Rp ${CurrencyUtils.formatPrice(amount)}',
          style: TextStyle(
            color: valueColor,
            fontSize: large ? 15 : 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
