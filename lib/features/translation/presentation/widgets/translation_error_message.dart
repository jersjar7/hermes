// lib/features/translation/presentation/widgets/translation_error_message.dart

import 'package:flutter/material.dart';

/// Widget to display error messages in the translation view with better visibility
class TranslationErrorMessage extends StatelessWidget {
  /// The error message to display
  final String message;

  /// Whether the error is related to permissions
  final bool isPermissionError;

  /// Callback for retry button
  final VoidCallback? onRetry;

  /// Callback for opening settings (for permission errors)
  final VoidCallback? onOpenSettings;

  /// Creates a new [TranslationErrorMessage]
  const TranslationErrorMessage({
    super.key,
    required this.message,
    this.isPermissionError = false,
    this.onRetry,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPermissionError ? Colors.orange.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isPermissionError ? Colors.orange.shade300 : Colors.red.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPermissionError ? Icons.mic_off : Icons.error_outline,
                color:
                    isPermissionError
                        ? Colors.orange.shade800
                        : Colors.red.shade800,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color:
                        isPermissionError
                            ? Colors.orange.shade800
                            : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Action buttons if needed
          if (onRetry != null || onOpenSettings != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Try Again'),
                    ),
                  if (onOpenSettings != null)
                    TextButton(
                      onPressed: onOpenSettings,
                      child: const Text('Open Settings'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
