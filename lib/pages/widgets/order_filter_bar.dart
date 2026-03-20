import 'package:flutter/material.dart';
import '../../helpers/date_utils.dart' as AppDateUtils;
import '../../helpers/status_utils.dart';
import '../../helpers/text_utils.dart';
import '../../constants.dart';
import 'filter_status_sheet.dart';

class OrderFilterBar extends StatelessWidget {
  final TextEditingController nameController;
  final String nameQuery;
  final DateTime? selectedDate;
  final String? selectedStatus;
  final List<String> statuses;
  final VoidCallback onPickDate;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onNameCleared;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onDateCleared;

  const OrderFilterBar({
    super.key,
    required this.nameController,
    required this.nameQuery,
    required this.selectedDate,
    required this.selectedStatus,
    required this.statuses,
    required this.onPickDate,
    required this.onNameChanged,
    required this.onNameCleared,
    required this.onStatusChanged,
    required this.onDateCleared,
  });

  static const Color _cyan   = AppColors.cyan;
  static const Color _cyanBg = AppColors.cyanBg;

  void _showFilterStatusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterStatusSheet(
        selectedStatus: selectedStatus,
        statuses: statuses,
        onSelect: onStatusChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDate   = selectedDate != null;
    final bool hasStatus = selectedStatus != null;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
      color: Color(0xFF0F1117),
      child: Column(children: [
        // Search by name
        Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Color(0xFF161B27),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFF222840), width: 1),
          ),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 16, color: Color(0xFF4A5568)),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: nameController,
                style: TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by customer name…',
                  hintStyle: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: onNameChanged,
              ),
            ),
            if (nameQuery.isNotEmpty)
              GestureDetector(
                onTap: onNameCleared,
                child: Icon(Icons.close_rounded, size: 15, color: Color(0xFF4A5568)),
              ),
          ]),
        ),

        SizedBox(height: 8),

        // Date + Status chips
        Row(children: [
          // Date chip
          Expanded(
            child: GestureDetector(
              onTap: onPickDate,
              child: Container(
                height: 36,
                padding: EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: hasDate ? _cyanBg : Color(0xFF161B27),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasDate
                        ? _cyan.withOpacity(0.4)
                        : Color(0xFF222840),
                    width: 1,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 13, color: hasDate ? _cyan : Color(0xFF4A5568)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasDate
                          ? AppDateUtils.DateUtils.formatFullDate(selectedDate!)
                          : 'All dates',
                      style: TextStyle(
                        color: hasDate ? _cyan : Color(0xFF4A5568),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasDate)
                    GestureDetector(
                      onTap: onDateCleared,
                      child: Icon(Icons.close_rounded, size: 13, color: _cyan),
                    ),
                ]),
              ),
            ),
          ),

          SizedBox(width: 8),

          // Status chip
          Expanded(
            child: GestureDetector(
              onTap: () => _showFilterStatusPicker(context),
              child: Container(
                height: 36,
                padding: EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: hasStatus
                      ? (StatusUtils.statusStyle(selectedStatus!)['bg'] as Color)
                      : Color(0xFF161B27),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasStatus
                        ? (StatusUtils.statusStyle(selectedStatus!)['color'] as Color)
                            .withOpacity(0.4)
                        : Color(0xFF222840),
                    width: 1,
                  ),
                ),
                child: Row(children: [
                  Icon(
                    hasStatus
                        ? (StatusUtils.statusStyle(selectedStatus!)['icon'] as IconData)
                        : Icons.filter_list_rounded,
                    size: 13,
                    color: hasStatus
                        ? (StatusUtils.statusStyle(selectedStatus!)['color'] as Color)
                        : Color(0xFF4A5568),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasStatus
                          ? TextUtils.capitalize(selectedStatus!)
                          : 'All statuses',
                      style: TextStyle(
                        color: hasStatus
                            ? (StatusUtils.statusStyle(selectedStatus!)['color'] as Color)
                            : Color(0xFF4A5568),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasStatus)
                    GestureDetector(
                      onTap: () => onStatusChanged(null),
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: StatusUtils.statusStyle(selectedStatus!)['color'] as Color,
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
