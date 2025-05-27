// lib/features/session_host/presentation/pages/start_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// TODO: import your HostSessionController provider

class StartSessionPage extends ConsumerWidget {
  const StartSessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: watch your HostSessionController state
    return Scaffold(
      appBar: AppBar(title: const Text('Start Session')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select language:'),
            const SizedBox(height: 8),
            // TODO: Replace with DropdownButton for languages
            ElevatedButton(
              onPressed: () {
                // TODO: request mic permission and start session
                context.go('/host/code');
              },
              child: const Text('Start Session'),
            ),
          ],
        ),
      ),
    );
  }
}
