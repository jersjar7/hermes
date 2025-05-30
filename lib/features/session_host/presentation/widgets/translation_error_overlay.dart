// lib/features/session_host/presentation/widgets/translation_error_overlay.dart

import 'package:flutter/material.dart';

/// An inline overlay widget to display translation errors.
///
/// Place this inside a Stack above the content that might fail, for example:
/// ```dart
/// Stack(
///   children: [
///     // ... your normal page content ...
///     if (translationError != null)
///       TranslationErrorOverlay(
///         message: translationError,
///         onRetry: () => retryTranslation(),
///       ),
///   ],
/// )
/// ```
class TranslationErrorOverlay extends StatelessWidget {
  /// The error message to show.
  final String message;

  /// Optional callback to retry the translation.
  final VoidCallback? onRetry;

  const TranslationErrorOverlay({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Translation Error',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      backgroundColor: Colors.white,
                    ),
                    onPressed: onRetry,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
