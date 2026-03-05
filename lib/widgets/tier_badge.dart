import 'package:flutter/material.dart';
import '../config/theme.dart';

class TierBadge extends StatelessWidget {
  final int tier;
  final double size;

  const TierBadge({super.key, required this.tier, this.size = 24});

  @override
  Widget build(BuildContext context) {
    if (tier < 0) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _gradient,
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _label,
          style: TextStyle(
            fontSize: size * 0.45,
            fontWeight: FontWeight.bold,
            color: tier == 0 ? Colors.white : Colors.white,
          ),
        ),
      ),
    );
  }

  String get _label {
    switch (tier) {
      case 3:
        return '3';
      case 2:
        return '2';
      case 1:
        return '1';
      default:
        return '0';
    }
  }

  Color get _primaryColor {
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

  LinearGradient get _gradient {
    switch (tier) {
      case 3:
        return const LinearGradient(
          colors: [DeskTheme.goldPrimary, DeskTheme.goldLight],
        );
      case 2:
        return const LinearGradient(
          colors: [DeskTheme.silverPrimary, DeskTheme.silverLight],
        );
      case 1:
        return const LinearGradient(
          colors: [DeskTheme.bronzePrimary, DeskTheme.bronzeLight],
        );
      default:
        return const LinearGradient(
          colors: [DeskTheme.trashColor, Color(0xFFA0A0A0)],
        );
    }
  }
}
