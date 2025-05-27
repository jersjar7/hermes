// lib/features/app/presentation/providers/app_router.dart

import 'package:go_router/go_router.dart';
import 'package:hermes/features/app/presentation/pages/generic_error_page.dart';
import 'package:hermes/features/app/presentation/pages/home_page.dart';
import 'package:hermes/features/app/presentation/pages/splash_screen_page.dart';
import 'package:hermes/features/session_host/presentation/pages/start_session_page.dart';
import 'package:hermes/features/session_host/presentation/pages/session_code_display_page.dart';
import 'package:hermes/features/session_host/presentation/pages/host_live_session_page.dart';

/// Centralized router for Hermes App Shell
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
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
    // Host flow
    GoRoute(
      path: '/host',
      name: 'host_start',
      builder: (context, state) => const StartSessionPage(),
    ),
    GoRoute(
      path: '/host/code',
      name: 'host_code',
      builder: (context, state) {
        final code = state.extra as String? ?? '';
        return SessionCodeDisplayPage(sessionCode: code);
      },
    ),
    GoRoute(
      path: '/host/live',
      name: 'host_live',
      builder: (context, state) => const HostLiveSessionPage(),
    ),
  ],
  errorBuilder:
      (context, state) =>
          GenericErrorPage(error: state.error, location: state.uri.toString()),
);
