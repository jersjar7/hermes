// lib/features/app/presentation/providers/app_router.dart

import 'package:go_router/go_router.dart';
import 'package:hermes/features/app/presentation/pages/generic_error_page.dart';
import 'package:hermes/features/app/presentation/pages/home_page.dart';
import 'package:hermes/features/app/presentation/pages/splash_screen_page.dart';
import 'package:hermes/features/session_host/presentation/pages/start_session_page.dart';
import 'package:hermes/features/session_host/presentation/pages/session_code_display_page.dart';
import 'package:hermes/features/session_host/presentation/pages/session_qr_code_page.dart';
import 'package:hermes/features/session_host/presentation/pages/host_waiting_room_page.dart';
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

    // ─── Host Flow ─────────────────────────────────────────────────────────────
    GoRoute(
      path: '/host',
      name: 'host_start',
      builder: (context, state) => const StartSessionPage(),
    ),
    GoRoute(
      path: '/host/code',
      name: 'host_code',
      builder: (context, state) => const SessionCodeDisplayPage(),
    ),
    GoRoute(
      path: '/host/qr',
      name: 'host_qr',
      builder: (context, state) => const SessionQRCodePage(),
    ),
    GoRoute(
      path: '/host/waiting',
      name: 'host_waiting',
      builder: (context, state) => const HostWaitingRoomPage(),
    ),
    GoRoute(
      path: '/host/live',
      name: 'host_live',
      builder: (context, state) => const HostLiveSessionPage(),
    ),
  ],

  // Error page
  errorBuilder:
      (context, state) =>
          GenericErrorPage(error: state.error, location: state.uri.toString()),
);
