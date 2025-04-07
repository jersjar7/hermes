// lib/features/session/presentation/widgets/session_code_card.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/utils/extensions.dart';

/// Widget to display session code in a card format
class SessionCodeCard extends StatelessWidget {
  /// Session code to display
  final String sessionCode;

  /// Callback for when copy button is tapped
  final VoidCallback onCopyTap;

  /// Creates a new [SessionCodeCard]
  const SessionCodeCard({
    super.key,
    required this.sessionCode,
    required this.onCopyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Session Code', style: context.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Display code with monospace font for better readability
                Text(
                  sessionCode,
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: onCopyTap,
                  tooltip: 'Copy to clipboard',
                  color: context.theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
