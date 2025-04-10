// lib/routes.dart

import 'package:flutter/material.dart';
import 'package:hermes/features/audience/presentation/pages/audience_home_page.dart';
import 'package:hermes/features/home/presentation/pages/home_screen.dart'; // New import path
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/presentation/pages/active_session_page.dart';
import 'package:hermes/features/session/presentation/pages/join_session_page.dart';
import 'package:hermes/features/session/presentation/pages/session_start_page.dart';
import 'package:hermes/features/session/presentation/pages/session_summary_page.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';

/// Route names used throughout the app
class AppRoutes {
  /// Home route
  static const String home = '/';

  /// Speaker session start route
  static const String sessionStart = '/session/start';

  /// Active session route for speaker
  static const String activeSession = '/session/active';

  /// Join session route for audience
  static const String joinSession = '/join';

  /// Audience session view route
  static const String audienceView = '/audience/view';

  /// Settings route
  static const String settings = '/settings';

  /// Profile route
  static const String profile = '/profile';

  /// About route
  static const String about = '/about';

  /// Summary route
  static const String sessionSummary = '/session/summary';
}

/// App router handling app navigation
class AppRouter {
  /// Generate route for the given route settings
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case AppRoutes.sessionStart:
        return MaterialPageRoute(builder: (_) => const SessionStartPage());

      case AppRoutes.activeSession:
        final session = settings.arguments as Session;
        return MaterialPageRoute(
          builder: (_) => ActiveSessionPage(session: session),
        );

      case AppRoutes.sessionSummary:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder:
              (_) => SessionSummaryPage(
                session: args['session'] as Session,
                transcripts: args['transcripts'] as List<Transcript>,
                audienceCount: args['audienceCount'] as int,
                sessionDuration: args['sessionDuration'] as Duration,
              ),
        );

      case AppRoutes.joinSession:
        return MaterialPageRoute(builder: (_) => const JoinSessionPage());

      case AppRoutes.audienceView:
        final args = settings.arguments as Map<String, dynamic>;
        final session = args['session'] as Session;
        final language = args['language'] as LanguageSelection;

        return MaterialPageRoute(
          builder:
              (_) => AudienceHomePage(session: session, language: language),
        );

      case AppRoutes.settings:
        return MaterialPageRoute(
          builder:
              (_) => const Scaffold(
                body: Center(child: Text('Settings Page Placeholder')),
              ),
        );

      case AppRoutes.profile:
        return MaterialPageRoute(
          builder:
              (_) => const Scaffold(
                body: Center(child: Text('Profile Page Placeholder')),
              ),
        );

      case AppRoutes.about:
        return MaterialPageRoute(
          builder:
              (_) => const Scaffold(
                body: Center(child: Text('About Page Placeholder')),
              ),
        );

      default:
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
                body: Center(child: Text('Route ${settings.name} not found')),
              ),
        );
    }
  }
}
