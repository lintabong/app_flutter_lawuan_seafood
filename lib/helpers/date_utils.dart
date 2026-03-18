
import 'package:flutter/material.dart';

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

  static Map<String, dynamic> statusStyle(String? s) {
    switch (s) {

      case 'pending':
        return {
          'color': const Color(0xFFF59E0B),
          'bg': const Color(0xFF2D1F0A),
          'icon': Icons.hourglass_empty_rounded
        };

      case 'prepared':
        return {
          'color': const Color(0xFF06B6D4),
          'bg': const Color(0xFF0C2A3A),
          'icon': Icons.kitchen_rounded
        };

      case 'paid':
        return {
          'color': const Color(0xFF6C63FF),
          'bg': const Color(0xFF1E1B4B),
          'icon': Icons.payments_rounded
        };

      case 'delivered':
        return {
          'color': const Color(0xFF10B981),
          'bg': const Color(0xFF062318),
          'icon': Icons.task_alt_rounded
        };

      case 'cancelled':
        return {
          'color': const Color(0xFFEF4444),
          'bg': const Color(0xFF2D0A0A),
          'icon': Icons.cancel_outlined
        };

      default:
        return {
          'color': const Color(0xFF94A3B8),
          'bg': const Color(0xFF1A1F2E),
          'icon': Icons.circle_outlined
        };
    }
  }

}