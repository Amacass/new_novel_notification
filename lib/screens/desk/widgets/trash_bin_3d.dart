import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A 3D trash bin viewed from above at an angle.
class TrashBin3D extends StatefulWidget {
  final int count;
  final bool isHighlighted;
  final bool isReceiving;
  final VoidCallback? onTap;

  const TrashBin3D({
    super.key,
    this.count = 0,
    this.isHighlighted = false,
    this.isReceiving = false,
    this.onTap,
  });

  @override
  State<TrashBin3D> createState() => _TrashBin3DState();
}

class _TrashBin3DState extends State<TrashBin3D>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  double _pulseScale = 1.0;

  @override
  void didUpdateWidget(TrashBin3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReceiving && !oldWidget.isReceiving) {
      _triggerPulse();
    }
  }

  void _triggerPulse() {
    _pulseController?.dispose();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    final anim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(
      parent: _pulseController!,
      curve: Curves.easeOut,
    ));
    anim.addListener(() => setState(() => _pulseScale = anim.value));
    _pulseController!.forward();
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = (widget.isHighlighted ? 1.12 : 1.0) * _pulseScale;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 150),
        child: CustomPaint(
          size: const Size(64, 72),
          painter: _TrashBinPainter(
            isHighlighted: widget.isHighlighted,
            paperCount: widget.count,
          ),
        ),
      ),
    );
  }
}

class _TrashBinPainter extends CustomPainter {
  final bool isHighlighted;
  final int paperCount;

  _TrashBinPainter({
    required this.isHighlighted,
    required this.paperCount,
  });

  static const _bodyColor = Color(0xFF505050);
  static const _bodyDark = Color(0xFF383838);
  static const _rimColor = Color(0xFF686868);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // --- Shadow ---
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + 3, h - 4),
        width: w * 0.85,
        height: 14,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // --- Body (trapezoidal cylinder) ---
    final topWidth = w * 0.9;
    final bottomWidth = w * 0.7;
    final bodyTop = h * 0.2;
    final bodyBottom = h - 8;

    final bodyPath = Path()
      ..moveTo(cx - topWidth / 2, bodyTop)
      ..lineTo(cx - bottomWidth / 2, bodyBottom)
      ..lineTo(cx + bottomWidth / 2, bodyBottom)
      ..lineTo(cx + topWidth / 2, bodyTop)
      ..close();

    // Gradient for cylindrical look
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_bodyDark, _bodyColor, const Color(0xFF606060), _bodyColor, _bodyDark],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ).createShader(Rect.fromLTWH(0, bodyTop, w, bodyBottom - bodyTop)),
    );

    // --- Bottom ellipse ---
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, bodyBottom),
        width: bottomWidth,
        height: 10,
      ),
      Paint()..color = _bodyDark,
    );

    // --- Papers sticking out ---
    if (paperCount > 0) {
      final papers = math.min(paperCount, 4);
      for (int i = 0; i < papers; i++) {
        final angle = -0.3 + i * 0.2;
        final paperW = 18.0;
        final paperH = 12.0 + i * 3;
        final paperX = cx - 12 + i * 8.0;
        final paperY = bodyTop - paperH + 6;

        canvas.save();
        canvas.translate(paperX, paperY);
        canvas.rotate(angle);
        final paperRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, paperW, paperH),
          const Radius.circular(1),
        );
        canvas.drawRRect(
          paperRect,
          Paint()..color = Colors.white.withValues(alpha: 0.5 - i * 0.08),
        );
        canvas.restore();
      }
    }

    // --- Top rim (ellipse) ---
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, bodyTop),
        width: topWidth,
        height: 14,
      ),
      Paint()..color = _rimColor,
    );

    // --- Inner opening ---
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, bodyTop),
        width: topWidth - 6,
        height: 10,
      ),
      Paint()..color = const Color(0xFF282828),
    );

    // --- Rim highlight ---
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, bodyTop),
        width: topWidth - 2,
        height: 12,
      ),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.2),
    );

    // --- Highlight glow when targeted ---
    if (isHighlighted) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, h * 0.55),
          width: w,
          height: h * 0.8,
        ),
        Paint()
          ..color = Colors.red.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // --- Icon ---
    final iconPainter = TextPainter(
      text: const TextSpan(text: '🗑️', style: TextStyle(fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(cx - iconPainter.width / 2, h * 0.42),
    );

    // --- Label ---
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'ゴミ箱',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.white70,
          shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(cx - labelPainter.width / 2, h * 0.65),
    );
  }

  @override
  bool shouldRepaint(_TrashBinPainter old) =>
      old.isHighlighted != isHighlighted || old.paperCount != paperCount;
}
