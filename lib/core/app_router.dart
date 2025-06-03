// lib/core/app_router.dart

import 'package:go_router/go_router.dart';
import 'package:hermes/features/app/presentation/pages/generic_error_page.dart';
import 'package:hermes/features/app/presentation/pages/home_page.dart';
import 'package:hermes/features/app/presentation/pages/splash_screen_page.dart';
import 'package:hermes/features/session/presentation/pages/speaker_setup_page.dart';
import 'package:hermes/features/session/presentation/pages/audience_setup_page.dart';
import 'package:hermes/features/session/presentation/pages/speaker_active_page.dart';
import 'package:hermes/features/session/presentation/pages/audience_active_page.dart';

/// Centralized router for Hermes App with clean role-based navigation flow
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // App shell routes
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreenPage(),
    ),
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),

    // Speaker flow: Setup → Active
    GoRoute(
      path: '/speaker-setup',
      name: 'speaker-setup',
      builder: (context, state) => const SpeakerSetupPage(),
    ),
    GoRoute(
      path: '/speaker-active',
      name: 'speaker-active',
      builder: (context, state) => const SpeakerActivePage(),
    ),

    // Audience flow: Setup → Active
    GoRoute(
      path: '/audience-setup',
      name: 'audience-setup',
      builder: (context, state) => const AudienceSetupPage(),
    ),
    GoRoute(
      path: '/audience-active',
      name: 'audience-active',
      builder: (context, state) {
        // Extract language preferences from navigation extra data
        final extra = state.extra as Map<String, dynamic>?;

        return AudienceActivePage(
          targetLanguageCode: extra?['targetLanguageCode'] as String?,
          targetLanguageName: extra?['targetLanguageName'] as String?,
          languageFlag: extra?['languageFlag'] as String?,
        );
      },
    ),

    // Legacy routes (for backwards compatibility during transition)
    // TODO: Remove these after migration is complete
    GoRoute(path: '/host', redirect: (context, state) => '/speaker-setup'),
    GoRoute(path: '/join', redirect: (context, state) => '/audience-setup'),
    GoRoute(
      path: '/active-session',
      redirect: (context, state) => '/speaker-active', // Default to speaker
    ),
  ],

  // Error page for unknown routes
  errorBuilder:
      (context, state) =>
          GenericErrorPage(error: state.error, location: state.uri.toString()),
);
