
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
}