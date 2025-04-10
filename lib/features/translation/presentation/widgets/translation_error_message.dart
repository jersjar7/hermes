// lib/features/translation/presentation/widgets/translation_error_message.dart

import 'package:flutter/material.dart';

/// Widget to display error messages in the translation view
class TranslationErrorMessage extends StatelessWidget {
  /// The error message to display
  final String message;

  /// Creates a new [TranslationErrorMessage]
  const TranslationErrorMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade900, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red.shade900)),
          ),
        ],
      ),
    );
  }
}
