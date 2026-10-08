import 'package:flutter/material.dart';

import '../models/studio_event.dart';
import '../theme/app_colors.dart';

/// Reusable badge widget for displaying an event's effective status across screens.
class EventStatusBadge extends StatelessWidget {
  const EventStatusBadge({
    super.key,
    required this.event,
    this.compact = false,
    this.relativeTo,
  });

  final StudioEvent event;
  final bool compact;
  final DateTime? relativeTo;

  @override
  Widget build(BuildContext context) {
    final label = event.effectiveStatusLabel(relativeTo);
    final color = event.effectiveStatusColor(context, relativeTo);
    final icon = event.effectiveStatusIcon(relativeTo);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.16 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: compact ? 11 : 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compact ? 10.5 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
