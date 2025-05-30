// lib/features/session_host/presentation/pages/host_live_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/hermes_engine/state/hermes_session_state.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/features/session_host/presentation/widgets/connectivity_lost_banner.dart';

/// Live session page showing buffering, countdown, live transcript & translation, and stop control.
class HostLiveSessionPage extends ConsumerWidget {
  const HostLiveSessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(hermesControllerProvider);

    return asyncState.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (err, _) => Scaffold(
            appBar: AppBar(title: const Text('Live Session')),
            body: Center(child: Text('Error: $err')),
          ),
      data: (state) => _buildLiveSession(context, ref, state),
    );
  }

  Widget _buildLiveSession(
    BuildContext context,
    WidgetRef ref,
    HermesSessionState state,
  ) {
    final controller = ref.read(hermesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Live Session')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ConnectivityLostBanner(),
            const SizedBox(height: 16),

            // 1) Buffering indicator
            if (state.status == HermesStatus.buffering) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Buffering…'),
            ],

            // 2) Countdown before playback
            if (state.status == HermesStatus.countdown &&
                state.countdownSeconds != null) ...[
              Text('Starting in ${state.countdownSeconds} seconds'),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 16),

            // 3) Last raw transcript
            Text('You said:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(state.lastTranscript ?? '…'),
            const SizedBox(height: 16),

            // 4) Last translation
            Text(
              'Translation:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(state.lastTranslation ?? '…'),
            const SizedBox(height: 16),

            // 5) Buffer size info
            Text(
              'Buffered segments: ${state.buffer.length}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),

      // 6) Stop session control
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.stop),
            label: const Text('End Session'),
            onPressed: () async {
              await controller.stop();
              if (!context.mounted) return;
              context.go('/host');
            },
          ),
        ),
      ),
    );
  }
}
