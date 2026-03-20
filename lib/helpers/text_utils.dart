
import '../helpers/currency_utils.dart';

class TextUtils {

  static String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  static String buildFullInvoiceText(Map<String, dynamic> order) {
    final customer     = order['customers'] as Map? ?? {};
    final customerName = customer['name'];
    final phone        = customer['phone'] ?? '';
    final status       = order['status'] ?? '';
    final orderId      = order['id'];
    final items        = (order['order_items'] as List?) ?? [];
    final deliveryPrice = double.tryParse(order['delivery_price']?.toString() ?? '0') ?? 0;
    final total         = double.tryParse(order['total_amount']?.toString()   ?? '0') ?? 0;
    final lat  = customer['latitude'];
    final lng  = customer['longitude'];

    final buffer = StringBuffer();
    buffer.writeln("Order $orderId - $customerName | $phone | $status");

    if (lat != null && lng != null) {
      buffer.writeln("https://maps.google.com/maps?q=$lat,$lng");
    }

    for (final item in items) {
      final product        = item['products'] as Map? ?? {};
      final variant        = item['product_variants'] as Map? ?? {};
      final qty            = double.tryParse(item['quantity'].toString()) ?? 0;
      final price          = double.tryParse(item['sell_price'].toString()) ?? 0;
      final productNameRaw = product['name'] ?? '-';
      final productName    = productNameRaw.replaceAll(RegExp(r'\(.*?\)'), '').trim();
      final variantNameRaw = variant['name'] ?? '';
      final variantName    = variantNameRaw.toLowerCase() == 'default' ? '' : "[$variantNameRaw]";
      final unit           = variant['unit'] ?? variant['unit'] ?? '';
      final qtyStr         = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
      final label          = variantName.isNotEmpty ? "$productName $variantName" : productName;
      buffer.writeln(" - $label $qtyStr $unit ${CurrencyUtils.formatPrice(price * qty)}");
    }

    if (deliveryPrice > 0) {
      buffer.writeln('delivery ${CurrencyUtils.formatPrice(deliveryPrice)}');
    }
    buffer.writeln('');
    buffer.write('total: ${CurrencyUtils.formatPrice(total)}');

    return buffer.toString();
  }
}
