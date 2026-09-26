import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Shape of individual PIN burst particles.
enum ParticleShape { circle, diamond, star, spark }

/// Immutable particle particle physics descriptor.
class _PinParticle {
  _PinParticle({
    required this.angle,
    required this.initialSpeed,
    required this.size,
    required this.color,
    required this.shape,
    required this.rotationSpeed,
    required this.gravity,
  });

  final double angle;
  final double initialSpeed;
  final double size;
  final Color color;
  final ParticleShape shape;
  final double rotationSpeed;
  final double gravity;

  factory _PinParticle.random(math.Random random) {
    const colors = [
      Color(0xFF818CF8), // Periwinkle Iris
      Color(0xFF38BDF8), // Sky Blue
      Color(0xFF34D399), // Pastel Mint
      Color(0xFFFBBF24), // Radiant Gold
      Color(0xFFF472B6), // Soft Rose
      Color(0xFFFFFFFF), // Pure Light
    ];

    final shapeIndex = random.nextInt(4);
    final shape = ParticleShape.values[shapeIndex];

    return _PinParticle(
      angle: random.nextDouble() * 2 * math.pi,
      initialSpeed: 45.0 + random.nextDouble() * 95.0,
      size: 2.2 + random.nextDouble() * 3.6,
      color: colors[random.nextInt(colors.length)],
      shape: shape,
      rotationSpeed: (random.nextDouble() - 0.5) * 6.0,
      gravity: 30.0 + random.nextDouble() * 40.0,
    );
  }
}

/// A high-performance 60/120Hz Particle Burst Painter optimized for Play Store standards.
///
/// Features:
/// - Zero allocations in `paint()` via pre-allocated shared Paint and Path.
/// - Self-terminating animation ticker to preserve mobile device battery life.
/// - Dynamic particle drag physics, gravity, alpha-fading, and sparkle rotation.
class _ParticleBurstPainter extends CustomPainter {
  _ParticleBurstPainter({
    required this.animation,
    required this.particles,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_PinParticle> particles;

  static final Paint _paint = Paint()..isAntiAlias = true;
  static final Path _starPath = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    if (progress <= 0.0 || progress >= 1.0 || particles.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    // Deceleration curve for initial explosive burst
    final t = Curves.easeOutQuad.transform(progress);
    // Alpha fades quickly in the last 40% of duration
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final distance = p.initialSpeed * t;
      final dx = center.dx + math.cos(p.angle) * distance;
      final dy = center.dy +
          math.sin(p.angle) * distance +
          (p.gravity * progress * progress);

      final currentSize = (p.size * (1.0 - progress * 0.7)).clamp(0.5, 8.0);
      final particleColor = p.color.withValues(alpha: alpha);

      _paint.color = particleColor;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotationSpeed * progress);

      switch (p.shape) {
        case ParticleShape.circle:
          _paint.style = PaintingStyle.fill;
          canvas.drawCircle(Offset.zero, currentSize, _paint);
          // Subtle glow ring
          _paint.style = PaintingStyle.stroke;
          _paint.strokeWidth = 0.8;
          _paint.color = particleColor.withValues(alpha: alpha * 0.4);
          canvas.drawCircle(Offset.zero, currentSize * 1.5, _paint);
          break;

        case ParticleShape.diamond:
          _paint.style = PaintingStyle.fill;
          _starPath.reset();
          _starPath.moveTo(0, -currentSize * 1.2);
          _starPath.lineTo(currentSize * 0.8, 0);
          _starPath.lineTo(0, currentSize * 1.2);
          _starPath.lineTo(-currentSize * 0.8, 0);
          _starPath.close();
          canvas.drawPath(_starPath, _paint);
          break;

        case ParticleShape.star:
          _paint.style = PaintingStyle.fill;
          _starPath.reset();
          for (int i = 0; i < 4; i++) {
            final a = i * math.pi / 2;
            final cosA = math.cos(a);
            final sinA = math.sin(a);
            if (i == 0) {
              _starPath.moveTo(cosA * currentSize * 1.4, sinA * currentSize * 1.4);
            } else {
              _starPath.lineTo(cosA * currentSize * 1.4, sinA * currentSize * 1.4);
            }
            final aMid = a + math.pi / 4;
            _starPath.lineTo(
              math.cos(aMid) * currentSize * 0.4,
              math.sin(aMid) * currentSize * 0.4,
            );
          }
          _starPath.close();
          canvas.drawPath(_starPath, _paint);
          break;

        case ParticleShape.spark:
          _paint.style = PaintingStyle.stroke;
          _paint.strokeWidth = 1.2;
          canvas.drawLine(
            Offset(-currentSize, 0),
            Offset(currentSize, 0),
            _paint,
          );
          canvas.drawLine(
            Offset(0, -currentSize),
            Offset(0, currentSize),
            _paint,
          );
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleBurstPainter oldDelegate) {
    return oldDelegate.animation.value != animation.value;
  }
}

/// A single interactive PIN Box with particle burst & spring bounce feedback.
class PinParticleBox extends StatefulWidget {
  const PinParticleBox({
    super.key,
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
    this.isDark = true,
    this.boxWidth = 46.0,
    this.boxHeight = 54.0,
  });

  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  final bool isDark;
  final double boxWidth;
  final double boxHeight;

  @override
  State<PinParticleBox> createState() => PinParticleBoxState();
}

class PinParticleBoxState extends State<PinParticleBox>
    with TickerProviderStateMixin {
  late final AnimationController _particleController;
  late final AnimationController _bounceController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  final math.Random _random = math.Random();
  final List<_PinParticle> _particles = [];
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();

    // 1. Particle Controller: 450ms explosive burst
    _particleController = AnimationController(
      vsync: this,
      duration: AppMotion.delight,
    );

    // 2. Box Bounce & Glow Pulse Controller: 240ms spring
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.16)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.16, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
    ]).animate(_bounceController);

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 70,
      ),
    ]).animate(_bounceController);

    widget.focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    _particleController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  /// Triggers the particle burst & box spring bounce.
  ///
  /// Can be called programmatically for auto-fill cascades.
  void triggerParticleBurst() {
    if (!mounted) return;

    if (!AppMotion.areAnimationsDisabled(context)) {
      // Generate 18 fresh particles
      _particles.clear();
      for (int i = 0; i < 20; i++) {
        _particles.add(_PinParticle.random(_random));
      }

      _particleController.forward(from: 0.0);
      _bounceController.forward(from: 0.0);
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.isNotEmpty;
    final isDark = widget.isDark;

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. Particle Canvas Overlay (bursts outward without clipping)
          Positioned(
            width: widget.boxWidth * 3.4,
            height: widget.boxHeight * 3.4,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _ParticleBurstPainter(
                    animation: _particleController,
                    particles: _particles,
                  ),
                ),
              ),
            ),
          ),

          // 2. Animated PIN Box
          AnimatedBuilder(
            animation: _bounceController,
            builder: (context, child) {
              final scale = _scaleAnimation.value;
              final glow = _glowAnimation.value;

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.boxWidth,
                  height: widget.boxHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      if (glow > 0.01)
                        BoxShadow(
                          color: AppColors.sky.withValues(alpha: 0.45 * glow),
                          blurRadius: 16 * glow,
                          spreadRadius: 2.5 * glow,
                        ),
                      if (_isFocused && glow <= 0.01)
                        BoxShadow(
                          color: AppColors.sky.withValues(alpha: 0.22),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.backspace &&
                    widget.controller.text.isEmpty) {
                  widget.onBackspace();
                }
              },
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextMain,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: hasValue
                      ? (isDark
                          ? AppColors.sky.withValues(alpha: 0.15)
                          : AppColors.sky.withValues(alpha: 0.08))
                      : (isDark
                          ? AppColors.glassInnerDark
                          : AppColors.lightInputFill),
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: hasValue
                          ? AppColors.sky.withValues(alpha: 0.55)
                          : (isDark
                              ? AppColors.glassBorderDark
                              : AppColors.lightBorder),
                      width: hasValue ? 1.4 : 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.sky,
                      width: 2.0,
                    ),
                  ),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty) {
                    triggerParticleBurst();
                  }
                  widget.onChanged(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A comprehensive 6-digit PIN Particle Entry Row with auto-fill cascade support.
class PinParticleField extends StatefulWidget {
  const PinParticleField({
    super.key,
    required this.controllers,
    required this.focusNodes,
    required this.onCompleted,
    this.onChanged,
    this.isDark = true,
  }) : assert(controllers.length == 6 && focusNodes.length == 6);

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final ValueChanged<String> onCompleted;
  final VoidCallback? onChanged;
  final bool isDark;

  @override
  State<PinParticleField> createState() => PinParticleFieldState();
}

class PinParticleFieldState extends State<PinParticleField> {
  final List<GlobalKey<PinParticleBoxState>> _boxKeys =
      List.generate(6, (_) => GlobalKey<PinParticleBoxState>());

  /// Programmatically fills the PIN digits with a delightful staggered particle cascade.
  void setDigitsWithCascade(String code) {
    final clean = code.replaceAll(RegExp(r'\D'), '');
    for (int i = 0; i < 6 && i < clean.length; i++) {
      widget.controllers[i].text = clean[i];
      final boxIndex = i;
      Future.delayed(Duration(milliseconds: i * 45), () {
        if (mounted) {
          _boxKeys[boxIndex].currentState?.triggerParticleBurst();
        }
      });
    }

    if (clean.length >= 6) {
      widget.focusNodes[5].unfocus();
      widget.onCompleted(clean.substring(0, 6));
    } else if (clean.isNotEmpty) {
      widget.focusNodes[clean.length].requestFocus();
    }
  }

  void _onDigitChanged(int index, String value) {
    widget.onChanged?.call();

    // Pasted multiple digits
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      setDigitsWithCascade(digits);
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        widget.focusNodes[index + 1].requestFocus();
      } else {
        widget.focusNodes[index].unfocus();
      }
    }

    final code = widget.controllers.map((c) => c.text.trim()).join();
    if (code.length == 6) {
      widget.onCompleted(code);
    }
  }

  void _onBackspace(int index) {
    if (index > 0) {
      widget.focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return PinParticleBox(
          key: _boxKeys[index],
          index: index,
          controller: widget.controllers[index],
          focusNode: widget.focusNodes[index],
          isDark: widget.isDark,
          onChanged: (val) => _onDigitChanged(index, val),
          onBackspace: () => _onBackspace(index),
        );
      }),
    );
  }
}
