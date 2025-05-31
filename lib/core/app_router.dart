// lib/core/app_router.dart

import 'package:go_router/go_router.dart';
import 'package:hermes/features/app/presentation/pages/generic_error_page.dart';
import 'package:hermes/features/app/presentation/pages/home_page.dart';
import 'package:hermes/features/app/presentation/pages/splash_screen_page.dart';
import 'package:hermes/features/session/presentation/pages/host_session_page.dart';
import 'package:hermes/features/session/presentation/pages/join_session_page.dart';
import 'package:hermes/features/session/presentation/pages/active_session_page.dart';

/// Centralized router for Hermes App with complete navigation flow
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

    // Session routes
    GoRoute(
      path: '/host',
      name: 'host',
      builder: (context, state) => const HostSessionPage(),
    ),
    GoRoute(
      path: '/join',
      name: 'join',
      builder: (context, state) => const JoinSessionPage(),
    ),
    GoRoute(
      path: '/active-session',
      name: 'active-session',
      builder: (context, state) => const ActiveSessionPage(),
    ),
  ],

  // Error page for unknown routes
  errorBuilder:
      (context, state) =>
          GenericErrorPage(error: state.error, location: state.uri.toString()),
);
