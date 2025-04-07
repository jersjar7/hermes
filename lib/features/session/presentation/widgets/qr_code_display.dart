// lib/features/session/presentation/widgets/qr_code_display.dart

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Widget to display QR code for a session
class QrCodeDisplay extends StatelessWidget {
  /// Session code to encode in QR
  final String sessionCode;

  /// Size of the QR code
  final double size;

  /// Creates a new [QrCodeDisplay]
  const QrCodeDisplay({super.key, required this.sessionCode, this.size = 200});

  @override
  Widget build(BuildContext context) {
    // Create data to encode in QR code (app-specific format)
    // In a real app, you might use a JSON string or custom URI scheme
    final qrData = 'hermes://join?code=$sessionCode';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: QrImageView(
          data: qrData,
          version: QrVersions.auto,
          size: size,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          errorStateBuilder: (context, error) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 60),
                  const SizedBox(height: 8),
                  Text(
                    'Error generating QR code',
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
