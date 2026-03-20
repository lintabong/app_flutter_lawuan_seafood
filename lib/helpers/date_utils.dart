

class DateUtils {
  static String formatFullDate(DateTime d) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];

    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  static bool isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year &&
        d.month == now.month &&
        d.day == now.day;
  }

  String formatDateTime(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${dt.day} ${m[dt.month - 1]} ${dt.year}, ${_pad(dt.hour)}:${_pad(dt.minute)}";
    } catch (_) { 
      return raw; 
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
