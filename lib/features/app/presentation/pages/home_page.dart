// lib/features/app/presentation/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const double _buttonWidth = 200;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HermesAppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _buttonWidth,
              child: ElevatedButton(
                onPressed: () => context.go('/host'),
                child: const Text('Start Session'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: _buttonWidth,
              child: OutlinedButton(
                onPressed: () => context.go('/join'),
                child: const Text('Join Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
