// lib/features/session_host/presentation/pages/host_live_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HostLiveSessionPage extends ConsumerWidget {
  const HostLiveSessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: watch transcript and translation buffers from HostSessionController
    return Scaffold(
      appBar: AppBar(title: const Text('Live Session')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Live Transcript:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                color: Colors.grey.shade200,
                child: const Center(child: Text('Transcript goes here...')),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Translated Buffer:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                color: Colors.grey.shade100,
                child: const Center(child: Text('Translations go here...')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
