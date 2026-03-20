import 'package:flutter/material.dart';
import '../../helpers/status_utils.dart';
import '../../helpers/text_utils.dart';
import '../../constants.dart';

class FilterStatusSheet extends StatelessWidget {
  final String? selectedStatus;
  final List<String> statuses;
  final void Function(String? status) onSelect;

  const FilterStatusSheet({
    super.key,
    required this.selectedStatus,
    required this.statuses,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF161B27),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Color(0xFF222840), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 18),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Filter by Status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 12),
          // "All" option
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 2),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(0xFF1A2035),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.all_inclusive_rounded,
                  color: Color(0xFF64748B), size: 18),
            ),
            title: Text(
              'All statuses',
              style: TextStyle(
                color: selectedStatus == null ? Colors.white : Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: selectedStatus == null
                ? Icon(Icons.check_rounded, color: AppColors.cyan, size: 18)
                : null,
            onTap: () {
              Navigator.pop(context);
              onSelect(null);
            },
          ),
          ...statuses.map((s) {
            final st        = StatusUtils.statusStyle(s);
            final color     = st['color'] as Color;
            final isCurrent = s == selectedStatus;
            return ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 2),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: st['bg'],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(st['icon'], color: color, size: 18),
              ),
              title: Text(
                TextUtils.capitalize(s),
                style: TextStyle(
                  color: isCurrent ? color : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: isCurrent
                  ? Icon(Icons.check_rounded, color: color, size: 18)
                  : null,
              onTap: () {
                Navigator.pop(context);
                onSelect(s);
              },
            );
          }),
          SizedBox(height: 28),
        ],
      ),
    );
  }
}