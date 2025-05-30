// lib/features/session_host/presentation/pages/session_code_display_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes/features/session_host/presentation/providers/host_session_controller.dart';
import 'package:hermes/features/session_host/presentation/widgets/connectivity_lost_banner.dart';

/// Displays the generated session code and navigation options.
class SessionCodeDisplayPage extends ConsumerWidget {
  const SessionCodeDisplayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostSessionControllerProvider);
    final code = state.sessionCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Session Code')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            code == null
                ? const Center(child: Text('No session code available.'))
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ConnectivityLostBanner(),
                    const SizedBox(height: 16),
                    const Text(
                      'Your session code is:',
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      code,
                      style: const TextStyle(
                        fontSize: 32,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy code',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code copied')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Show QR Code'),
                      onPressed: () => context.go('/host/qr'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      child: const Text('Go to Waiting Room'),
                      onPressed: () => context.go('/host/waiting'),
                    ),
                  ],
                ),
      ),
    );
  }
}
