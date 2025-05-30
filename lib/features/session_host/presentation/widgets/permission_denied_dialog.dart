// lib/features/session_host/presentation/widgets/permission_denied_dialog.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// A dialog shown when the user has denied microphone permission,
/// prompting them to grant it in their device settings.
class PermissionDeniedDialog extends StatelessWidget {
  const PermissionDeniedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Microphone Permission Required'),
      content: const Text(
        'This feature requires access to your microphone. '
        'Please enable microphone permission in your device settings to continue.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            openAppSettings(); // from permission_handler
            Navigator.of(context).pop();
          },
          child: const Text('Open Settings'),
        ),
      ],
    );
  }
}
