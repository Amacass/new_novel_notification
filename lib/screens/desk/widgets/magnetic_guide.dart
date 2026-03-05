import 'package:flutter/material.dart';
import '../../../config/theme.dart';

/// Shows a glowing directional guide from the card stack toward
/// the target tray when the user is dragging a card.
class MagneticGuide extends StatelessWidget {
  final int? activeTier;

  const MagneticGuide({super.key, this.activeTier});

  @override
  Widget build(BuildContext context) {
    if (activeTier == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _MagneticGuidePainter(
            tier: activeTier!,
            size: Size(constraints.maxWidth, constraints.maxHeight),
          ),
        );
      },
    );
  }
}

class _MagneticGuidePainter extends CustomPainter {
  final int tier;
  final Size size;

  _MagneticGuidePainter({required this.tier, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Card stack center position (matches desk_screen layout)
    final cardCenter = Offset(size.width / 2, size.height * 0.52);

    // Tray target positions (match desk_screen layout)
    final target = _targetForTier(tier);

    final color = _colorForTier;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withValues(alpha: 0.25);

    // Draw curved guide path from card to tray
    final midX = (cardCenter.dx + target.dx) / 2;
    final midY = (cardCenter.dy + target.dy) / 2;
    // Add some curve perpendicular to the line
    final dx = target.dx - cardCenter.dx;
    final dy = target.dy - cardCenter.dy;
    final perpX = -dy * 0.15;
    final perpY = dx * 0.15;

    final path = Path()
      ..moveTo(cardCenter.dx, cardCenter.dy)
      ..quadraticBezierTo(
        midX + perpX,
        midY + perpY,
        target.dx,
        target.dy,
      );

    // Dashed effect
    canvas.drawPath(path, paint);

    // Glow at target
    canvas.drawCircle(
      target,
      20,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );

    // Arrow at target
    canvas.drawCircle(
      target,
      6,
      Paint()..color = color.withValues(alpha: 0.5),
    );
  }

  Offset _targetForTier(int tier) {
    switch (tier) {
      case 3: // Gold: top center
        return Offset(size.width / 2, size.height * 0.1);
      case 2: // Silver: upper right
        return Offset(size.width * 0.78, size.height * 0.26);
      case 1: // Bronze: upper left
        return Offset(size.width * 0.22, size.height * 0.26);
      default: // Trash: bottom center
        return Offset(size.width / 2, size.height * 0.85);
    }
  }

  Color get _colorForTier {
    switch (tier) {
      case 3:
        return DeskTheme.goldPrimary;
      case 2:
        return DeskTheme.silverPrimary;
      case 1:
        return DeskTheme.bronzePrimary;
      default:
        return DeskTheme.trashColor;
    }
  }

  @override
  bool shouldRepaint(_MagneticGuidePainter old) => old.tier != tier;
}
