import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../config/theme.dart';

/// A 3D perspective desk tray viewed from above at an angle.
/// Uses CustomPainter to draw a tray with visible rim, interior, and papers.
class Tray3D extends StatefulWidget {
  final int tier;
  final int count;
  final bool isHighlighted;
  final bool isReceiving;
  final VoidCallback? onTap;

  const Tray3D({
    super.key,
    required this.tier,
    this.count = 0,
    this.isHighlighted = false,
    this.isReceiving = false,
    this.onTap,
  });

  @override
  State<Tray3D> createState() => _Tray3DState();
}

class _Tray3DState extends State<Tray3D> with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  AnimationController? _pulseController;
  double _pulseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.tier == 3) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(Tray3D oldWidget) {
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
    _shimmerController.dispose();
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
        child: AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(110, 72),
              painter: _Tray3DPainter(
                tier: widget.tier,
                isHighlighted: widget.isHighlighted,
                shimmerValue: widget.tier == 3 ? _shimmerController.value : 0,
                paperCount: widget.count,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Tray3DPainter extends CustomPainter {
  final int tier;
  final bool isHighlighted;
  final double shimmerValue;
  final int paperCount;

  _Tray3DPainter({
    required this.tier,
    required this.isHighlighted,
    required this.shimmerValue,
    required this.paperCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Perspective: back edge narrower than front
    final backInset = w * 0.12;
    final rimH = 8.0;
    final innerRimH = 6.0;

    final colors = _colorsForTier;

    // --- Drop shadow ---
    final shadowPath = Path()
      ..moveTo(5, h + 3)
      ..lineTo(w + 3, h + 3)
      ..lineTo(w - backInset + 3, 3)
      ..lineTo(backInset + 3, 3)
      ..close();
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // --- Back rim ---
    final backRimPath = Path()
      ..moveTo(backInset, 0)
      ..lineTo(w - backInset, 0)
      ..lineTo(w - backInset - 2, innerRimH)
      ..lineTo(backInset + 2, innerRimH)
      ..close();
    canvas.drawPath(backRimPath, Paint()..color = colors.rim.withValues(alpha: 0.6));

    // --- Left rim ---
    final leftRimPath = Path()
      ..moveTo(backInset, 0)
      ..lineTo(0, h)
      ..lineTo(innerRimH * 0.7, h - innerRimH)
      ..lineTo(backInset + 2, innerRimH)
      ..close();
    canvas.drawPath(leftRimPath, Paint()..color = colors.rim.withValues(alpha: 0.75));

    // --- Right rim ---
    final rightRimPath = Path()
      ..moveTo(w - backInset, 0)
      ..lineTo(w, h)
      ..lineTo(w - innerRimH * 0.7, h - innerRimH)
      ..lineTo(w - backInset - 2, innerRimH)
      ..close();
    canvas.drawPath(rightRimPath, Paint()..color = colors.rim.withValues(alpha: 0.65));

    // --- Tray interior (bottom surface) ---
    final interiorPath = Path()
      ..moveTo(backInset + 2, innerRimH)
      ..lineTo(w - backInset - 2, innerRimH)
      ..lineTo(w - innerRimH * 0.7, h - innerRimH)
      ..lineTo(innerRimH * 0.7, h - innerRimH)
      ..close();
    final interiorRect =
        Rect.fromLTWH(0, 0, w, h);
    canvas.drawPath(
      interiorPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.interior, colors.interiorDark],
        ).createShader(interiorRect),
    );

    // --- Papers inside tray ---
    if (paperCount > 0) {
      final papers = math.min(paperCount, 5);
      for (int i = papers - 1; i >= 0; i--) {
        final paperH = 8.0;
        final paperY = h - innerRimH - 6 - (i * 5.0);
        final paperInset = backInset + 6 + (i * 1.5);
        final angle = (i % 2 == 0 ? 1 : -1) * 0.03 * (i + 1);

        canvas.save();
        canvas.translate(w / 2, paperY);
        canvas.rotate(angle);

        // Paper shadow
        final shadowRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: const Offset(1, 1.5),
            width: w - paperInset * 2,
            height: paperH,
          ),
          const Radius.circular(1),
        );
        canvas.drawRRect(
          shadowRect,
          Paint()..color = Colors.black.withValues(alpha: 0.2),
        );

        // Paper body
        final paperRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: w - paperInset * 2,
            height: paperH,
          ),
          const Radius.circular(1),
        );
        canvas.drawRRect(
          paperRect,
          Paint()..color = Color.lerp(
            const Color(0xFFFFFDF5),
            const Color(0xFFEDE8D8),
            i / 5,
          )!,
        );

        canvas.restore();
      }

      // Paper count badge
      if (paperCount > 1) {
        final badgeText = TextPainter(
          text: TextSpan(
            text: '$paperCount',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        badgeText.paint(
          canvas,
          Offset(w - backInset - badgeText.width - 4, innerRimH + 3),
        );
      }
    }

    // --- Front rim (most prominent) ---
    final frontRimPath = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(w - innerRimH * 0.7, h - rimH)
      ..lineTo(innerRimH * 0.7, h - rimH)
      ..close();
    canvas.drawPath(
      frontRimPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.rimDark, colors.rim],
        ).createShader(Rect.fromLTWH(0, h - rimH, w, rimH)),
    );

    // --- Front rim highlight ---
    final highlightPath = Path()
      ..moveTo(w * 0.15, h - 1)
      ..lineTo(w * 0.85, h - 1)
      ..lineTo(w * 0.8, h - rimH * 0.4)
      ..lineTo(w * 0.2, h - rimH * 0.4)
      ..close();
    canvas.drawPath(
      highlightPath,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    // --- Gold shimmer ---
    if (tier == 3 && shimmerValue > 0) {
      final shimmerX = (shimmerValue * 3 - 1) * w;
      final shimmerGradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      final shimmerRect =
          Rect.fromLTWH(shimmerX - 30, 0, 60, h);
      canvas.save();
      canvas.clipPath(Path()
        ..moveTo(0, h)
        ..lineTo(w, h)
        ..lineTo(w - backInset, 0)
        ..lineTo(backInset, 0)
        ..close());
      canvas.drawRect(
        shimmerRect,
        Paint()..shader = shimmerGradient.createShader(shimmerRect),
      );
      canvas.restore();
    }

    // --- Highlight glow when card dragged toward this tray ---
    if (isHighlighted) {
      final glowPath = Path()
        ..moveTo(0, h)
        ..lineTo(w, h)
        ..lineTo(w - backInset, 0)
        ..lineTo(backInset, 0)
        ..close();
      canvas.drawPath(
        glowPath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // --- Tier icon and label ---
    _drawText(canvas, size);
  }

  void _drawText(Canvas canvas, Size size) {
    final icon = DeskTheme.tierIcon(tier);
    final label = DeskTheme.tierLabel(tier);

    // Icon
    final iconPainter = TextPainter(
      text: TextSpan(text: icon, style: const TextStyle(fontSize: 20)),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset((size.width - iconPainter.width) / 2, size.height * 0.18),
    );

    // Label
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: tier == 0 ? Colors.white70 : Colors.white,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset((size.width - labelPainter.width) / 2, size.height * 0.58),
    );
  }

  _TrayColors get _colorsForTier {
    switch (tier) {
      case 3:
        return _TrayColors(
          rim: const Color(0xFFDAA520),
          rimDark: const Color(0xFFB8860B),
          interior: const Color(0xFFFFF8DC),
          interiorDark: const Color(0xFFEED9A0),
        );
      case 2:
        return _TrayColors(
          rim: const Color(0xFFC0C0C0),
          rimDark: const Color(0xFF909090),
          interior: const Color(0xFFF0F0F0),
          interiorDark: const Color(0xFFD8D8D8),
        );
      case 1:
        return _TrayColors(
          rim: const Color(0xFF8B6914),
          rimDark: const Color(0xFF6B4F10),
          interior: const Color(0xFFDEB887),
          interiorDark: const Color(0xFFC4A06A),
        );
      default:
        return _TrayColors(
          rim: const Color(0xFF606060),
          rimDark: const Color(0xFF404040),
          interior: const Color(0xFF808080),
          interiorDark: const Color(0xFF606060),
        );
    }
  }

  @override
  bool shouldRepaint(_Tray3DPainter old) =>
      old.tier != tier ||
      old.isHighlighted != isHighlighted ||
      old.shimmerValue != shimmerValue ||
      old.paperCount != paperCount;
}

class _TrayColors {
  final Color rim;
  final Color rimDark;
  final Color interior;
  final Color interiorDark;

  const _TrayColors({
    required this.rim,
    required this.rimDark,
    required this.interior,
    required this.interiorDark,
  });
}
