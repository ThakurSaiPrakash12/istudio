import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Smooth counting financial text widget.
/// Smoothly transitions currency and numerical values when payment, balance,
/// earnings, or profit states change.
class AnimatedFinancialText extends StatelessWidget {
  const AnimatedFinancialText({
    super.key,
    required this.amount,
    this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOutCubic,
    this.prefix = '',
    this.suffix = '',
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final num amount;
  final String Function(num value)? formatter;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final String prefix;
  final String suffix;
  final TextAlign? textAlign;
  final int maxLines;
  final TextOverflow overflow;

  static final _defaultCurrency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  String _format(num value) {
    if (formatter != null) return formatter!(value);
    return _defaultCurrency.format(value.round());
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(
        '$prefix${_format(amount)}$suffix',
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: amount.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, val, _) {
        return Text(
          '$prefix${_format(val)}$suffix',
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}
