// lib/features/session/presentation/controllers/session_code_input_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/session_validators.dart';

/// State for session code input field.
/// Tracks value, validation, and formatting.
class SessionCodeState {
  final String value;
  final String? error;
  final bool isValid;
  final String formatted;

  const SessionCodeState({
    required this.value,
    this.error,
    required this.isValid,
    required this.formatted,
  });

  /// Creates empty initial state.
  factory SessionCodeState.empty() {
    return const SessionCodeState(value: '', isValid: false, formatted: '');
  }

  /// Creates state from a code value.
  factory SessionCodeState.fromCode(String code) {
    final upperCode = code.toUpperCase();
    final error = SessionValidators.validateSessionCode(upperCode);

    return SessionCodeState(
      value: upperCode,
      error: error,
      isValid: error == null,
      formatted:
          upperCode.length == 6
              ? SessionValidators.formatSessionCode(upperCode)
              : upperCode,
    );
  }

  /// Whether the code is complete (6 chars).
  bool get isComplete => value.length == 6;

  /// Whether to show error (complete but invalid).
  bool get shouldShowError => isComplete && !isValid;
}

/// Controls session code input state.
class SessionCodeInputController extends StateNotifier<SessionCodeState> {
  SessionCodeInputController() : super(SessionCodeState.empty());

  /// Updates the code value and validates.
  void updateCode(String value) {
    // Remove spaces and limit to 6 chars
    final cleaned = value.replaceAll(' ', '').toUpperCase();
    if (cleaned.length > 6) return;

    state = SessionCodeState.fromCode(cleaned);
  }

  /// Clears the current code.
  void clear() {
    state = SessionCodeState.empty();
  }

  /// Attempts to submit the code.
  /// Returns true if valid, false otherwise.
  bool submit() {
    if (!state.isValid) {
      // Re-validate to show error
      state = SessionCodeState.fromCode(state.value);
      return false;
    }
    return true;
  }
}

/// Provider for session code input controller.
final sessionCodeInputProvider =
    StateNotifierProvider<SessionCodeInputController, SessionCodeState>((ref) {
      return SessionCodeInputController();
    });
