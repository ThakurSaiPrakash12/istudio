import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Liquid Glass styled countdown chip with urgency-coded glowing indicators
class CountdownChip extends StatelessWidget {
  const CountdownChip({
    super.key,
    required this.daysLeft,
    required this.hoursLeft,
    this.compact = false,
  });

  final int daysLeft;
  final int hoursLeft;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.urgencyColor(
      context,
      daysLeft,
      hoursLeft,
    );
    final isUrgent = daysLeft == 0;

    final String text;
    if (daysLeft == 0 && hoursLeft <= 0) {
      text = compact ? 'Today' : '🔥 Today';
    } else if (daysLeft >= 1) {
      text = compact
          ? '${daysLeft}d ${hoursLeft}h'
          : '⏳ ${daysLeft}d ${hoursLeft}h left';
    } else {
      text = compact
          ? '${hoursLeft}h left'
          : '🚨 ${hoursLeft}h left';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.55),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.7),
                  blurRadius: isUrgent ? 6 : 3,
                  spreadRadius: isUrgent ? 1 : 0.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
