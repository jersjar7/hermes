// lib/features/session/presentation/widgets/pre_speaking_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hermes/core/utils/extensions.dart';
import 'package:hermes/features/session/presentation/widgets/qr_code_display.dart';
import 'package:hermes/features/session/presentation/widgets/session_code_card.dart';

/// View shown before the speaker starts speaking
class PreSpeakingView extends StatelessWidget {
  /// Session name
  final String sessionName;

  /// Session code
  final String sessionCode;

  /// Callback for when the copy button is tapped
  final VoidCallback onCopyTap;

  /// Creates a new [PreSpeakingView]
  const PreSpeakingView({
    super.key,
    required this.sessionName,
    required this.sessionCode,
    required this.onCopyTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Session name
            Text(
              sessionName,
              style: context.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Session code card
            SessionCodeCard(sessionCode: sessionCode, onCopyTap: onCopyTap),

            const SizedBox(height: 24),

            // QR code
            QrCodeDisplay(sessionCode: sessionCode),

            const SizedBox(height: 8),

            Text(
              'Share this code or QR with your audience',
              style: context.textTheme.bodyMedium,
            ),

            const SizedBox(height: 32),

            // Start speaking guidance
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Ready to Begin?',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Press the "Start Speaking" button below when you\'re ready to begin your session. Your speech will be transcribed and translated in real-time for your audience.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Copy session code to clipboard
  static void copyToClipboard(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session code copied to clipboard')),
    );
  }
}
