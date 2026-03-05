import 'package:flutter/material.dart';

/// A wood-grain desk surface with 3D perspective effect.
class DeskBackground extends StatelessWidget {
  final Widget child;

  const DeskBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF2A1F0E), // far edge
                  Color(0xFF3E2F14),
                  Color(0xFF4D3A18),
                  Color(0xFF5A441E), // near edge
                ]
              : const [
                  Color(0xFF6B4F10), // far edge
                  Color(0xFF8B6914),
                  Color(0xFF9D7B1C),
                  Color(0xFFAE8C28), // near edge
                ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _WoodGrainPainter(isDark: isDark),
        child: child,
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  final bool isDark;

  _WoodGrainPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04)
      ..strokeWidth = 0.8;

    for (double y = 20; y < size.height; y += 18) {
      final path = Path();
      path.moveTo(0, y);
      path.quadraticBezierTo(
        size.width / 2,
        y + 2,
        size.width,
        y - 1,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WoodGrainPainter old) => old.isDark != isDark;
}
