// lib/features/session_host/presentation/pages/session_qr_code_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/features/session_host/presentation/widgets/connectivity_lost_banner.dart';

/// Page that renders a QR code for the current session code.
class SessionQRCodePage extends ConsumerWidget {
  const SessionQRCodePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch engine state to ensure a session is active
    final asyncState = ref.watch(hermesControllerProvider);

    return asyncState.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (err, _) => Scaffold(
            appBar: AppBar(title: const Text('Session QR Code')),
            body: Center(child: Text('Error: $err')),
          ),
      data: (_) {
        // Get the current session code from the core session service
        final sessionService = getIt<ISessionService>();
        final code = sessionService.currentSession?.sessionId;

        return Scaffold(
          appBar: AppBar(title: const Text('Session QR Code')),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ConnectivityLostBanner(),
              Expanded(
                child: Center(
                  child:
                      code == null
                          ? const Text('No session code to show.')
                          : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
              ),
            ],
          ),
        );
      },
    );
  }
}
