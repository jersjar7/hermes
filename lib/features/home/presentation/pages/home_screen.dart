// lib/features/home/presentation/pages/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hermes/routes.dart';

/// Home screen of the application
class HomeScreen extends StatelessWidget {
  /// Creates a new [HomeScreen] instance
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF9F9FB), Color(0xFFEDEBFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Image.asset(
                    'assets/img/HermesTransparentBG.png',
                    height: 220,
                  ).animate().fadeIn(duration: 2000.ms).slideY(begin: 0.2),

                  const SizedBox(height: 22),

                  // Title
                  Text(
                    'Welcome to Hermes',
                    style: GoogleFonts.sora(
                      textStyle: theme.textTheme.headlineSmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate().fadeIn(duration: 2500.ms).slideY(begin: 0.2),

                  const SizedBox(height: 12),

                  // Tagline/subtext
                  Text(
                    'Real-time translation for everyone',
                    style: GoogleFonts.sora(
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ).animate().fadeIn(duration: 600.ms),

                  const SizedBox(height: 48),

                  // Start as Speaker button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.mic),
                      label: const Text('Start as Speaker'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.sessionStart);
                      },
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),

                  const SizedBox(height: 16),

                  // Join as Audience button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.headphones),
                      label: const Text('Join as Audience'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.primary.withOpacity(0.6),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.joinSession);
                      },
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),

                  const SizedBox(height: 32),

                  // Optional "How it works" text
                  TextButton(
                    onPressed: () {
                      // Optional: show modal or route to info screen
                    },
                    child: Text(
                      'How it works',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        color: Colors.grey[600],
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ).animate().fadeIn(duration: 600.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
