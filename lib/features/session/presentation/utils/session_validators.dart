// lib/features/session/presentation/utils/session_validators.dart

/// Validation utilities for session-related inputs.
/// All functions are pure and return validation results.
class SessionValidators {
  // Prevent instantiation
  SessionValidators._();

  /// Valid characters for session codes (no ambiguous letters).
  /// Excludes: 0, O, 1, I to avoid confusion.
  static const String validChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Validates a session code.
  /// Returns null if valid, error message if invalid.
  static String? validateSessionCode(String? code) {
    if (code == null || code.isEmpty) {
      return 'Session code is required';
    }

    final upperCode = code.toUpperCase();

    if (upperCode.length != 6) {
      return 'Session code must be 6 characters';
    }

    for (final char in upperCode.split('')) {
      if (!validChars.contains(char)) {
        return 'Invalid character: $char';
      }
    }

    return null; // Valid
  }

  /// Formats a session code for display.
  /// Adds spacing for readability: ABC123 → ABC 123
  static String formatSessionCode(String code) {
    if (code.length != 6) return code;
    return '${code.substring(0, 3)} ${code.substring(3)}';
  }

  /// Validates a language code (BCP-47 format).
  /// Examples: en-US, es-MX, zh-CN
  static String? validateLanguageCode(String? code) {
    if (code == null || code.isEmpty) {
      return 'Language code is required';
    }

    final pattern = RegExp(r'^[a-z]{2}(-[A-Z]{2})?$');
    if (!pattern.hasMatch(code)) {
      return 'Invalid language code format';
    }

    return null; // Valid
  }
}
