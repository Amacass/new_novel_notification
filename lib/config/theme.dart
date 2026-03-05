import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// Skeuomorphic design tokens for the Desk Triage UI
class DeskTheme {
  // Desk background - wood grain gradient
  static const deskGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B6914), Color(0xFF6B4F10), Color(0xFF5A3E0E)],
  );

  static const deskGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3D2E0A), Color(0xFF2E2308), Color(0xFF1F1806)],
  );

  // Card paper texture
  static const cardColor = Color(0xFFF5F0E1); // beige
  static const cardColorDark = Color(0xFF2C2820);
  static const cardBorderRadius = 8.0;
  static BoxDecoration cardDecoration({bool isDark = false}) => BoxDecoration(
        color: isDark ? cardColorDark : cardColor,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      );

  // Tier tray colors
  static const goldPrimary = Color(0xFFDAA520);
  static const goldLight = Color(0xFFFFD700);
  static const silverPrimary = Color(0xFFC0C0C0);
  static const silverLight = Color(0xFFE8E8E8);
  static const bronzePrimary = Color(0xFFCD7F32);
  static const bronzeLight = Color(0xFFDEA05C);
  static const trashColor = Color(0xFF808080);

  static BoxDecoration trayDecoration(int tier, {bool isDark = false}) {
    final baseAlpha = isDark ? 0.3 : 0.15;
    switch (tier) {
      case 3:
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [goldPrimary, goldLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: goldPrimary.withValues(alpha: baseAlpha + 0.1),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        );
      case 2:
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [silverPrimary, silverLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: silverPrimary.withValues(alpha: baseAlpha),
              blurRadius: 8,
            ),
          ],
        );
      case 1:
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [bronzePrimary, bronzeLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: bronzePrimary.withValues(alpha: baseAlpha),
              blurRadius: 8,
            ),
          ],
        );
      default: // 0 = trash
        return BoxDecoration(
          color: isDark ? const Color(0xFF404040) : trashColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: baseAlpha),
              blurRadius: 6,
            ),
          ],
        );
    }
  }

  // Tier labels
  static String tierLabel(int tier) {
    switch (tier) {
      case 3:
        return '殿堂入り';
      case 2:
        return '良作';
      case 1:
        return 'キープ';
      case 0:
        return 'ゴミ箱';
      default:
        return '未仕分け';
    }
  }

  static String tierIcon(int tier) {
    switch (tier) {
      case 3:
        return '👑';
      case 2:
        return '⭐';
      case 1:
        return '📌';
      case 0:
        return '🗑️';
      default:
        return '📋';
    }
  }
}

class AppTheme {
  static ThemeData light() {
    return FlexThemeData.light(
      scheme: FlexScheme.indigo,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        useM2StyleDividerInM3: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: 12.0,
        cardRadius: 12.0,
        elevatedButtonRadius: 12.0,
        filledButtonRadius: 12.0,
        outlinedButtonRadius: 12.0,
        bottomNavigationBarSelectedLabelSize: 12,
        bottomNavigationBarUnselectedLabelSize: 10,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    return FlexThemeData.dark(
      scheme: FlexScheme.indigo,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 13,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        useM2StyleDividerInM3: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: 12.0,
        cardRadius: 12.0,
        elevatedButtonRadius: 12.0,
        filledButtonRadius: 12.0,
        outlinedButtonRadius: 12.0,
        bottomNavigationBarSelectedLabelSize: 12,
        bottomNavigationBarUnselectedLabelSize: 10,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
    );
  }
}
