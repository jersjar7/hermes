// lib/features/session/presentation/widgets/session_action_bar.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/utils/extensions.dart';

/// Bottom action bar for the active session page
class SessionActionBar extends StatelessWidget {
  /// Whether the speaker is currently listening
  final bool isListening;

  /// Whether listening is paused
  final bool isPaused;

  /// Whether the session is ending
  final bool isEnding;

  /// Callback for the main action button (start/pause/resume)
  final VoidCallback onMainActionPressed;

  /// Callback for ending the session
  final VoidCallback onEndSessionPressed;

  /// Creates a new [SessionActionBar]
  const SessionActionBar({
    super.key,
    required this.isListening,
    required this.isPaused,
    required this.isEnding,
    required this.onMainActionPressed,
    required this.onEndSessionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Start/Pause/Resume button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onMainActionPressed,
              icon: Icon(_getButtonIcon()),
              label: Text(_getButtonLabel()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getButtonColor(context),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // End session button
          ElevatedButton.icon(
            onPressed: isEnding ? null : onEndSessionPressed,
            icon:
                isEnding
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.close),
            label: const Text('End Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade800,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Get the appropriate icon for the main button
  IconData _getButtonIcon() {
    if (!isListening) return Icons.mic;
    return isPaused ? Icons.play_arrow : Icons.pause;
  }

  /// Get the appropriate label for the main button
  String _getButtonLabel() {
    if (!isListening) return 'Start Speaking';
    return isPaused ? 'Resume Speaking' : 'Pause Speaking';
  }

  /// Get the appropriate color for the main button
  Color _getButtonColor(BuildContext context) {
    if (!isListening) return context.theme.colorScheme.primary;
    return isPaused ? Colors.amber : Colors.green;
  }
}
