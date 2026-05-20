import 'package:flutter/material.dart';

class SportalBackground extends StatelessWidget {
  const SportalBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SvgBackgroundPainter(), child: child);
  }
}

class _SvgBackgroundPainter extends CustomPainter {
  static const double svgWidth = 402;
  static const double svgHeight = 874;

  static const Color _glowFull = Color(0xFF1A4FB8);
  static const Color _glowNone = Color(0x001A4FB8);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / svgWidth;
    final scaleY = size.height / svgHeight;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0E1A3D),
    );

    Offset pos(double x, double y) => Offset(x * scaleX, y * scaleY);
    double r(double v) => v * scaleX * 1.15;

    void glow(Offset center, double radius, double peak) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              Color.lerp(_glowNone, _glowFull, peak)!,
              Color.lerp(_glowNone, _glowFull, peak * 0.55)!,
              Color.lerp(_glowNone, _glowFull, peak * 0.14)!,
              _glowNone,
            ],
            stops: const [0.0, 0.38, 0.68, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(pos(104, 86), r(270), 0.60);
    glow(pos(402, 525), r(310), 0.48);
    glow(pos(22, 720), r(290), 0.44);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
