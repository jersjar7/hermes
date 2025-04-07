// lib/features/home/presentation/pages/home_screen.dart

import 'package:flutter/material.dart';
import 'package:hermes/routes.dart';

/// Home screen of the application
class HomeScreen extends StatelessWidget {
  /// Creates a new [HomeScreen] instance
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hermes')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Hermes',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.sessionStart);
              },
              child: const Text('Start as Speaker'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.joinSession);
              },
              child: const Text('Join as Audience'),
            ),
          ],
        ),
      ),
    );
  }
}
