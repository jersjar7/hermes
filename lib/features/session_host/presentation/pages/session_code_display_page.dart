// lib/features/session_host/presentation/pages/session_code_display_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SessionCodeDisplayPage extends StatelessWidget {
  final String sessionCode;
  const SessionCodeDisplayPage({super.key, required this.sessionCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Code')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Your session code:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(sessionCode, style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/host/live'),
              child: const Text('Continue to Session'),
            ),
          ],
        ),
      ),
    );
  }
}
