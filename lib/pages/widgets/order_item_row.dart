
import 'package:flutter/material.dart';
import '../../helpers/currency_utils.dart';

class OrderItemRow extends StatelessWidget {
  final Map item;
  final bool isLoading;
  final VoidCallback onTap;

  const OrderItemRow({
    super.key,
    required this.item,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final product = item['products'] as Map? ?? {};
    final variant = item['product_variants'] as Map?;
    final qty = double.tryParse(item['quantity'].toString()) ?? 0;
    final price = double.tryParse(item['sell_price'].toString()) ?? 0;
    final isPrepared = item['is_prepared'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Row(children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isPrepared ? Color(0xFF062318) : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: isPrepared ? Color(0xFF10B981) : Color(0xFF2A3040),
                width: 1.5,
              ),
            ),
            child: isLoading
                ? Padding(
                    padding: EdgeInsets.all(4),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFF10B981),
                    ),
                  )
                : isPrepared
                    ? Icon(Icons.check_rounded, size: 14, color: Color(0xFF10B981))
                    : null,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? '—',
                  style: TextStyle(
                    color: isPrepared ? Color(0xFF4A5568) : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: isPrepared ? TextDecoration.lineThrough : null,
                    decorationColor: Color(0xFF4A5568),
                  ),
                ),
                if (variant != null)
                  Text(
                    variant['name'] ?? '',
                    style: TextStyle(color: Color(0xFF6C63FF), fontSize: 10),
                  ),
              ],
            ),
          ),
          Text(
            "${qty % 1 == 0 ? qty.toInt() : qty} ${variant?['unit'] ?? ''}",
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          SizedBox(width: 12),
          Text(
            'Rp ${CurrencyUtils.formatPrice(qty * price)}',
            style: TextStyle(
              color: isPrepared ? Color(0xFF4A5568) : Color(0xFF10B981),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ),
    );
  }
}
