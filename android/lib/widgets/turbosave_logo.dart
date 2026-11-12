import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// TurboSave's compact brand mark: a T-shaped transfer arrow landing in a tray.
/// It is drawn as a vector so it stays crisp from navigation size to app icon size.
class TurboSaveLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool hasGlow;
  final bool showText;
  final TextStyle? textStyle;

  const TurboSaveLogo({
    super.key,
    this.size = 36,
    this.borderRadius = 10,
    this.hasGlow = false,
    this.showText = false,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? Colors.white : const Color(0xFF111111),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .28 : .16),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        painter: _TurboSaveMarkPainter(
          foreground: dark ? const Color(0xFF111111) : Colors.white,
          accent: const Color(0xFFB7F34A),
        ),
      ),
    );

    if (!showText) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        Text(
          'TurboSave',
          style:
              textStyle ??
              TextStyle(
                color: AppTheme.text(context),
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -.7,
              ),
        ),
      ],
    );
  }
}

class _TurboSaveMarkPainter extends CustomPainter {
  final Color foreground;
  final Color accent;
  const _TurboSaveMarkPainter({required this.foreground, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = foreground
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final topBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .23, h * .22, w * .54, h * .12),
      Radius.circular(w * .06),
    );
    canvas.drawRRect(topBar, paint);

    final arrow = Path()
      ..moveTo(w * .43, h * .29)
      ..quadraticBezierTo(w * .43, h * .27, w * .46, h * .27)
      ..lineTo(w * .54, h * .27)
      ..quadraticBezierTo(w * .57, h * .27, w * .57, h * .30)
      ..lineTo(w * .57, h * .56)
      ..lineTo(w * .68, h * .56)
      ..quadraticBezierTo(w * .72, h * .56, w * .69, h * .60)
      ..lineTo(w * .53, h * .76)
      ..quadraticBezierTo(w * .50, h * .79, w * .47, h * .76)
      ..lineTo(w * .31, h * .60)
      ..quadraticBezierTo(w * .28, h * .56, w * .32, h * .56)
      ..lineTo(w * .43, h * .56)
      ..close();
    canvas.drawPath(arrow, paint);

    canvas.drawCircle(
      Offset(w * .75, h * .75),
      w * .055,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _TurboSaveMarkPainter oldDelegate) =>
      oldDelegate.foreground != foreground || oldDelegate.accent != accent;
}
