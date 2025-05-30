// lib/features/session_host/presentation/pages/host_waiting_room_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes/features/session_host/presentation/providers/host_session_controller.dart';
import 'package:hermes/features/session_host/presentation/widgets/connectivity_lost_banner.dart';

/// Placeholder page shown while waiting for audience members or the first speech.
class HostWaitingRoomPage extends ConsumerWidget {
  const HostWaitingRoomPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostSessionControllerProvider);
    final controller = ref.read(hostSessionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Host Waiting Room')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ConnectivityLostBanner(),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Waiting for audience members to join…',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (state.sessionCode != null) ...[
              Text(
                'Session Code:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              SelectableText(
                state.sessionCode!,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
            if (state.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                await controller.stopSession();
                // Guard against using context if this widget was disposed
                if (!context.mounted) return;
                context.go('/host');
              },
              child: const Text('Stop Session'),
            ),
          ],
        ),
      ),
    );
  }
}
