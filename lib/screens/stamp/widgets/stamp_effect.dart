import 'dart:math' as math;
import 'package:flutter/material.dart';

enum StampEffectType {
  fireRise,
  rainDrop,
  leafFloat,
  heartRise,
  explosion,
  zFloat,
}

class StampEffect extends StatefulWidget {
  final StampEffectType type;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback? onComplete;

  const StampEffect({
    super.key,
    required this.type,
    required this.primaryColor,
    required this.secondaryColor,
    this.onComplete,
  });

  @override
  State<StampEffect> createState() => _StampEffectState();
}

class _StampEffectState extends State<StampEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _particles = _generateParticles();
    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  List<_Particle> _generateParticles() {
    final count = 30 + _random.nextInt(20); // 30-50 particles
    return List.generate(count, (i) {
      final color = _random.nextBool() ? widget.primaryColor : widget.secondaryColor;
      return _Particle(
        x: _random.nextDouble() * 2 - 1, // -1 to 1
        y: _random.nextDouble() * 2 - 1,
        vx: (_random.nextDouble() - 0.5) * _velocityScale,
        vy: _initialVy,
        size: 3 + _random.nextDouble() * 5,
        color: color,
        rotation: _random.nextDouble() * math.pi * 2,
        rotationSpeed: (_random.nextDouble() - 0.5) * 4,
      );
    });
  }

  double get _velocityScale {
    switch (widget.type) {
      case StampEffectType.explosion:
        return 3.0;
      case StampEffectType.fireRise:
      case StampEffectType.heartRise:
        return 1.0;
      default:
        return 0.8;
    }
  }

  double get _initialVy {
    switch (widget.type) {
      case StampEffectType.fireRise:
      case StampEffectType.heartRise:
        return -2.0 - _random.nextDouble(); // rise up
      case StampEffectType.rainDrop:
        return 1.5 + _random.nextDouble(); // fall down
      case StampEffectType.leafFloat:
        return -0.5 - _random.nextDouble() * 0.5;
      case StampEffectType.explosion:
        return (_random.nextDouble() - 0.5) * 3.0;
      case StampEffectType.zFloat:
        return -0.8 - _random.nextDouble() * 0.3;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _StampEffectPainter(
            particles: _particles,
            progress: _controller.value,
            type: widget.type,
          ),
        );
      },
    );
  }
}

class _Particle {
  double x, y, vx, vy, size, rotation, rotationSpeed;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _StampEffectPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final StampEffectType type;

  _StampEffectPainter({
    required this.particles,
    required this.progress,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final t = progress;
      final x = centerX + (p.x + p.vx * t) * size.width * 0.3;
      final y = centerY + (p.y + p.vy * t) * size.height * 0.3;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity * 0.8)
        ..style = PaintingStyle.fill;

      final particleSize = p.size * (1.0 - progress * 0.5);

      switch (type) {
        case StampEffectType.heartRise:
          _drawHeart(canvas, x, y, particleSize, paint);
        case StampEffectType.leafFloat:
          _drawLeaf(canvas, x, y, particleSize, p.rotation + p.rotationSpeed * t, paint);
        case StampEffectType.zFloat:
          _drawZ(canvas, x, y, particleSize, paint);
        default:
          canvas.drawCircle(Offset(x, y), particleSize, paint);
      }
    }
  }

  void _drawHeart(Canvas canvas, double x, double y, double size, Paint paint) {
    final path = Path();
    path.moveTo(x, y + size * 0.3);
    path.cubicTo(x - size, y - size * 0.5, x - size * 0.5, y - size, x, y - size * 0.3);
    path.cubicTo(x + size * 0.5, y - size, x + size, y - size * 0.5, x, y + size * 0.3);
    canvas.drawPath(path, paint);
  }

  void _drawLeaf(Canvas canvas, double x, double y, double size, double angle, Paint paint) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    final path = Path();
    path.moveTo(0, -size);
    path.quadraticBezierTo(size * 0.8, 0, 0, size);
    path.quadraticBezierTo(-size * 0.8, 0, 0, -size);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawZ(Canvas canvas, double x, double y, double size, Paint paint) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Z',
        style: TextStyle(
          color: paint.color,
          fontSize: size * 3,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(_StampEffectPainter old) => old.progress != progress;
}

