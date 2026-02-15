import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

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
