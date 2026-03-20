import 'package:flutter/material.dart';
import '../../helpers/status_utils.dart';
import '../../helpers/text_utils.dart';

class StatusPickerSheet extends StatelessWidget {
  final String currentStatus;
  final List<String> statuses;
  final bool Function(String from, String to) requiresRpc;
  final void Function(String status) onSelect;

  const StatusPickerSheet({
    super.key,
    required this.currentStatus,
    required this.statuses,
    required this.requiresRpc,
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
              'Update Status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 12),
          ...statuses.map((s) {
            final st        = StatusUtils.statusStyle(s);
            final color     = st['color'] as Color;
            final isCurrent = s == currentStatus;
            final needsRpc  = requiresRpc(currentStatus, s);
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
              subtitle: needsRpc
                  ? Row(children: [
                      Icon(Icons.bolt_rounded, size: 11, color: Color(0xFF10B981)),
                      SizedBox(width: 3),
                      Text(
                        'Applies cash inflow',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 11),
                      ),
                    ])
                  : null,
              trailing: isCurrent
                  ? Icon(Icons.check_rounded, color: color, size: 18)
                  : null,
              onTap: isCurrent
                  ? null
                  : () {
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
