// lib/routes.dart

import 'package:flutter/material.dart';

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
}

/// App router handling app navigation
class AppRouter {
  /// Generate route for the given route settings
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(
          builder:
              (_) => const Scaffold(
                body: Center(child: Text('Home Page Placeholder')),
              ),
        );

      case AppRoutes.sessionStart:
        return MaterialPageRoute(
          builder:
              (_) => const Scaffold(
                body: Center(child: Text('Session Start Page Placeholder')),
              ),
        );

      case AppRoutes.activeSession:
        return MaterialPageRoute(
          builder:
              (_) => const Scaffold(
                body: Center(child: Text('Active Session Page Placeholder')),
              ),
        );

      case AppRoutes.joinSession:
        return MaterialPageRoute(
          builder:
              (_) => const Scaffold(
                body: Center(child: Text('Join Session Page Placeholder')),
              ),
        );

      case AppRoutes.audienceView:
        return MaterialPageRoute(
          builder:
              (_) => const Scaffold(
                body: Center(child: Text('Audience View Page Placeholder')),
              ),
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
