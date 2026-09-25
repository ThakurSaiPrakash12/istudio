import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// ShimmerBox — a single animated shimmer rectangle.
// GPU-composited via LinearGradient sweep; no Opacity widget.
// ---------------------------------------------------------------------------
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 18,
    this.borderRadius = 10,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect system reduce-motion accessibility setting
    if (MediaQuery.disableAnimationsOf(context)) {
      return _static(context);
    }

    final dark = context.isDark;
    final base = dark ? const Color(0xFF1C2232) : const Color(0xFFE8EAF0);
    final highlight = dark ? const Color(0xFF2A3350) : const Color(0xFFF5F6FA);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final v = _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [base, highlight, base],
              stops: [
                (v - 0.35).clamp(0.0, 1.0),
                v.clamp(0.0, 1.0),
                (v + 0.35).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _static(BuildContext context) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: context.isDark
              ? const Color(0xFF1C2232)
              : const Color(0xFFE8EAF0),
        ),
      );
}

// ---------------------------------------------------------------------------
// ShimmerCard — card-shaped skeleton that mirrors StudioCard's look.
// ---------------------------------------------------------------------------
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.rows = 3, this.height});

  final int rows;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? AppColors.glassCardDark : AppColors.lightCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? AppColors.glassBorderDark : AppColors.lightBorder,
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const ShimmerBox(width: 120, height: 14),
          const SizedBox(height: 14),
          for (int i = 0; i < rows; i++) ...[
            ShimmerBox(
              width: i == rows - 1 ? 160 : double.infinity,
              height: 12,
            ),
            if (i < rows - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ShimmerListItem — horizontal icon + two-line row skeleton.
// ---------------------------------------------------------------------------
class ShimmerListItem extends StatelessWidget {
  const ShimmerListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: const [
          ShimmerBox(width: 44, height: 44, borderRadius: 14),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 13),
                SizedBox(height: 8),
                ShimmerBox(width: 120, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EventDetailsShimmer — full-page skeleton for EventDetailsScreen.
// ---------------------------------------------------------------------------
class EventDetailsShimmer extends StatelessWidget {
  const EventDetailsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        ShimmerCard(rows: 4, height: 130),
        SizedBox(height: 16),
        ShimmerCard(rows: 3, height: 110),
        SizedBox(height: 16),
        ShimmerCard(rows: 2, height: 80),
        SizedBox(height: 16),
        ShimmerCard(rows: 4, height: 140),
      ],
    );
  }
}
