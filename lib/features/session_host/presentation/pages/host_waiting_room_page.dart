// lib/features/session_host/presentation/pages/host_waiting_room_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/features/session_host/presentation/widgets/connectivity_lost_banner.dart';

/// Placeholder page shown while waiting for audience members or the first speech.
class HostWaitingRoomPage extends ConsumerWidget {
  const HostWaitingRoomPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the Hermes engine state
    final asyncState = ref.watch(hermesControllerProvider);
    final controller = ref.read(hermesControllerProvider.notifier);

    return asyncState.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (err, _) => Scaffold(
            appBar: AppBar(title: const Text('Host Waiting Room')),
            body: Center(child: Text('Error: $err')),
          ),
      data: (_) {
        // Use core session service to get the code
        final sessionService = getIt<ISessionService>();
        final code = sessionService.currentSession?.sessionId;

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
                const Text(
                  'Waiting for audience members to join…',
                  style: TextStyle(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (code != null) ...[
                  Text(
                    'Session Code:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    code,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    await controller.stop();
                    if (!context.mounted) return;
                    context.go('/host');
                  },
                  child: const Text('Stop Session'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
