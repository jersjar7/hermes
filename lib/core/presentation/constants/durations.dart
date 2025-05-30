// lib/core/presentation/constants/durations.dart

import 'package:flutter/material.dart';

/// Standardized animation durations for consistent motion design.
/// All animations in Hermes should use these predefined durations.
class HermesDurations {
  // Prevent instantiation
  HermesDurations._();

  /// 150ms - Instant feedback (e.g., button press)
  static const Duration instant = Duration(milliseconds: 150);

  /// 200ms - Fast animations (e.g., small state changes)
  static const Duration fast = Duration(milliseconds: 200);

  /// 300ms - Normal animations (e.g., page transitions)
  static const Duration normal = Duration(milliseconds: 300);

  /// 500ms - Slow animations (e.g., complex transitions)
  static const Duration slow = Duration(milliseconds: 500);

  /// 1000ms - Very slow animations (e.g., onboarding)
  static const Duration verySlow = Duration(seconds: 1);

  /// Standard curve for most animations
  static const Curve defaultCurve = Curves.easeInOut;

  /// Curve for elements entering the screen
  static const Curve enterCurve = Curves.easeOut;

  /// Curve for elements leaving the screen
  static const Curve exitCurve = Curves.easeIn;

  /// Bounce curve for playful animations
  static const Curve bounceCurve = Curves.elasticOut;
}
