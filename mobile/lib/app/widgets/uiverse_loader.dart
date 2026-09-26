import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Pixel-perfect Flutter port of the alexruix Uiverse.io kinetic loader.
/// Features synchronized text letter-spacing/translation and expanding/sliding
/// capsule pill animation at 60/120 FPS.
class UiverseLoader extends StatefulWidget {
  const UiverseLoader({
    super.key,
    this.text = 'loading',
    this.textColor,
    this.pillColor,
    this.innerPillColor,
    this.scale = 1.0,
  });

  final String text;
  final Color? textColor;
  final Color? pillColor;
  final Color? innerPillColor;
  final double scale;

  @override
  State<UiverseLoader> createState() => _UiverseLoaderState();
}

class _UiverseLoaderState extends State<UiverseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- Keyframe Helper for Piecewise Interpolation ---
  double _interpolate({
    required double t,
    required List<double> stops,
    required List<double> values,
  }) {
    if (t <= stops.first) return values.first;
    if (t >= stops.last) return values.last;

    for (int i = 0; i < stops.length - 1; i++) {
      if (t >= stops[i] && t <= stops[i + 1]) {
        final segmentProgress = (t - stops[i]) / (stops[i + 1] - stops[i]);
        final curvedProgress = Curves.easeInOut.transform(segmentProgress);
        return values[i] + (values[i + 1] - values[i]) * curvedProgress;
      }
    }
    return values.last;
  }

  @override
  Widget build(BuildContext context) {
    // Default colors from Uiverse.io snippet:
    // Text: #C8B6FF, Pill: #9A79FF, Inner Pill: #D1C2FF
    final isDark = context.isDark;
    final textColor = widget.textColor ??
        (isDark ? const Color(0xFFC8B6FF) : const Color(0xFF7C3AED));
    final pillColor = widget.pillColor ??
        (isDark ? const Color(0xFF9A79FF) : const Color(0xFF6D28D9));
    final innerPillColor = widget.innerPillColor ??
        (isDark ? const Color(0xFFD1C2FF) : const Color(0xFFA78BFA));

    const totalWidth = 80.0;
    const totalHeight = 50.0;
    const pillHeight = 16.0;

    return Transform.scale(
      scale: widget.scale,
      child: SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;

            // @keyframes text_713:
            // 0%: letter-spacing: 1px, translateX(0px)
            // 40%: letter-spacing: 2px, translateX(26px)
            // 80%: letter-spacing: 1px, translateX(32px)
            // 90%: letter-spacing: 2px, translateX(0px)
            // 100%: letter-spacing: 1px, translateX(0px)
            final textDx = _interpolate(
              t: t,
              stops: [0.0, 0.40, 0.80, 0.90, 1.0],
              values: [0.0, 26.0, 32.0, 0.0, 0.0],
            );
            final textSpacing = _interpolate(
              t: t,
              stops: [0.0, 0.40, 0.80, 0.90, 1.0],
              values: [1.0, 2.0, 1.0, 2.0, 1.0],
            );

            // @keyframes loading_713 (.load):
            // 0%: width: 16px, translateX(0px)
            // 40%: width: 80px (100%), translateX(0px)
            // 80%: width: 16px, translateX(64px)
            // 90%: width: 80px (100%), translateX(0px)
            // 100%: width: 16px, translateX(0px)
            final loadWidth = _interpolate(
              t: t,
              stops: [0.0, 0.40, 0.80, 0.90, 1.0],
              values: [16.0, 80.0, 16.0, 80.0, 16.0],
            );
            final loadDx = _interpolate(
              t: t,
              stops: [0.0, 0.40, 0.80, 0.90, 1.0],
              values: [0.0, 0.0, 64.0, 0.0, 0.0],
            );

            // @keyframes loading2_713 (.load::before):
            // 0%: translateX(0px), width: 16px
            // 40%: translateX(0px), width: 80% (64px)
            // 80%: translateX(0px), width: 100% (80px)
            // 90%: translateX(15px), width: 80% (64px)
            // 100%: translateX(0px), width: 16px
            final innerWidthPercent = _interpolate(
              t: t,
              stops: [0.0, 0.40, 0.80, 0.90, 1.0],
              values: [1.0, 0.80, 1.0, 0.80, 1.0],
            );
            final innerDx = _interpolate(
              t: t,
              stops: [0.0, 0.40, 0.80, 0.90, 1.0],
              values: [0.0, 0.0, 0.0, 15.0, 0.0],
            );

            final innerWidth = (loadWidth * innerWidthPercent).clamp(10.0, loadWidth);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Animated text at top
                Positioned(
                  top: 0,
                  left: 0,
                  child: Transform.translate(
                    offset: Offset(textDx, 0),
                    child: Text(
                      widget.text,
                      style: GoogleFonts.plusJakartaSans(
                        color: textColor,
                        fontSize: 12.8, // approx .8rem
                        fontWeight: FontWeight.w600,
                        letterSpacing: textSpacing,
                      ),
                    ),
                  ),
                ),

                // Animated pill capsule at bottom (.load)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Transform.translate(
                    offset: Offset(loadDx, 0),
                    child: Container(
                      width: loadWidth,
                      height: pillHeight,
                      decoration: BoxDecoration(
                        color: pillColor,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          // Inner glowing pill (.load::before)
                          Positioned(
                            left: innerDx.clamp(0.0, loadWidth - innerWidth),
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: innerWidth,
                              decoration: BoxDecoration(
                                color: innerPillColor,
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
