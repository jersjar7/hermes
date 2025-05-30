// lib/features/session_host/presentation/pages/session_qr_code_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/features/session_host/presentation/widgets/connectivity_lost_banner.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Flutter widget for QR codes
import 'package:go_router/go_router.dart';
import 'package:hermes/features/session_host/presentation/providers/host_session_controller.dart';

/// Page that renders a QR code for the current session code.
class SessionQRCodePage extends ConsumerWidget {
  const SessionQRCodePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostSessionControllerProvider);
    final code = state.sessionCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Session QR Code')),
      body: Center(
        child:
            code == null
                ? const Text('No session code to show.')
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ConnectivityLostBanner(),
                    const SizedBox(height: 16),
                    // Use QrImageView from qr_flutter for proper named-parameter API
                    QrImageView(
                      data: code,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Scan to join:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      code,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.go('/host/code'),
                      child: const Text('Back to Code'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.go('/host/waiting'),
                      child: const Text('Enter Waiting Room'),
                    ),
                  ],
                ),
      ),
    );
  }
}
