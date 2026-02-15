import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_notification/config/theme.dart';

void main() {
  group('AppTheme', () {
    test('light() returns a ThemeData with light brightness', () {
      final theme = AppTheme.light();

      expect(theme, isA<ThemeData>());
      expect(theme.brightness, Brightness.light);
    });

    test('dark() returns a ThemeData with dark brightness', () {
      final theme = AppTheme.dark();

      expect(theme, isA<ThemeData>());
      expect(theme.brightness, Brightness.dark);
    });

    test('both themes use Material 3', () {
      expect(AppTheme.light().useMaterial3, isTrue);
      expect(AppTheme.dark().useMaterial3, isTrue);
    });
  });
}
