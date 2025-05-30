// lib/features/session_host/presentation/widgets/stt_error_dialog.dart

import 'package:flutter/material.dart';

/// A dialog shown when speech-to-text initialization or listening fails,
/// displaying the [error] and offering retry or cancel actions.
class STTErrorDialog extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const STTErrorDialog({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Speech Recognition Error'),
      content: Text(error, style: const TextStyle(color: Colors.redAccent)),
      actions: [
        if (onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry!();
            },
            child: const Text('Retry'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
