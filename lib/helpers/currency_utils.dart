
class CurrencyUtils {
  static String formatPrice(dynamic p) {
    if (p == null) return '0';

    final n = double.tryParse(p.toString()) ?? 0;
    final str = n.toStringAsFixed(0);
    final buf = StringBuffer();

    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(str[i]);
    }

    return buf.toString();
  }

  static String formatRupiah(double amount) {
    final intAmount = amount.toInt();
    final str = intAmount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      count++;
    }
    return 'Rp. ${buffer.toString().split('').reversed.join()}';
  }
}