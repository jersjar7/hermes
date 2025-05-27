// lib/features/app/presentation/pages/generic_error_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';

/// A fallback page for unknown routes or errors.
class GenericErrorPage extends StatelessWidget {
  /// The exception that occurred, if any.
  final Exception? error;

  /// The attempted route location.
  final String? location;

  const GenericErrorPage({super.key, this.error, this.location});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HermesAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Oops! Page not found.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (location != null) ...[
                Text(
                  'Route: $location',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
              ],
              if (error != null) ...[
                Text(
                  'Error: ${error.toString()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: () => context.goNamed('home'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
