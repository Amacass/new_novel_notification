import 'package:flutter/services.dart';

class AppHaptics {
  static void sortCard(int tier) {
    if (tier == 3) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  static void stampTap() {
    HapticFeedback.lightImpact();
  }

  static void complete() {
    HapticFeedback.heavyImpact();
  }

  static void undo() {
    HapticFeedback.lightImpact();
  }
}
