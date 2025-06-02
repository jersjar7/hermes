// lib/core/hermes_engine/hermes_controller.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/audience/audience_engine.dart';
import 'package:hermes/core/hermes_engine/buffer/countdown_timer.dart';
import 'package:hermes/core/hermes_engine/hermes_engine.dart';
import 'package:hermes/core/hermes_engine/speaker/speaker_engine.dart';
import 'package:hermes/core/hermes_engine/state/hermes_session_state.dart';
import 'package:hermes/core/hermes_engine/usecases/playback_control.dart';
import 'package:hermes/core/service_locator.dart';

/// Exposes the HermesEngine to the UI via Riverpod.
final hermesControllerProvider =
    AsyncNotifierProvider<HermesController, HermesSessionState>(
      HermesController.new,
    );

class HermesController extends AsyncNotifier<HermesSessionState> {
  // 🎯 CRITICAL CHANGE: Make engines nullable and create fresh instances per session
  HermesEngine? _engine;
  SpeakerEngine? _speakerEngine;
  AudienceEngine? _audienceEngine;
  StreamSubscription<HermesSessionState>? _subscription;
  bool _isSpeakerSession = false;

  @override
  Future<HermesSessionState> build() async {
    // 🎯 CRITICAL CHANGE: Don't create engines here - create them when needed
    // This prevents reusing closed StreamControllers

    // When the provider is disposed (e.g. on app exit), clean up everything
    ref.onDispose(() {
      _disposeCurrentEngines();
    });

    // Return the "idle" initial state
    return HermesSessionState.initial();
  }

  /// 🎯 NEW: Creates fresh engine instances for a new session
  void _createFreshEngines() {
    // Dispose old engines if they exist
    _disposeCurrentEngines();

    print('🔄 [HermesController] Creating fresh engine instances...');

    // Create fresh instances from service locator (now using factories)
    _speakerEngine = getIt<SpeakerEngine>();
    _audienceEngine = getIt<AudienceEngine>();
    final playbackCtrl = getIt<PlaybackControlUseCase>();
    final countdown = getIt<CountdownTimer>();

    _engine = HermesEngine(
      speakerEngine: _speakerEngine!,
      audienceEngine: _audienceEngine!,
      playbackControl: playbackCtrl,
      countdown: countdown,
    );

    print('✅ [HermesController] Created fresh engine instances');
  }

  /// 🎯 NEW: Dispose current engines properly
  void _disposeCurrentEngines() {
    print('🗑️ [HermesController] Disposing old engine instances...');

    _subscription?.cancel();
    _subscription = null;

    if (_speakerEngine != null) {
      _speakerEngine!.dispose();
      _speakerEngine = null;
    }

    if (_audienceEngine != null) {
      _audienceEngine!.dispose();
      _audienceEngine = null;
    }

    _engine = null;
    print('✅ [HermesController] Disposed old engine instances');
  }

  /// IMPROVED: Start a speaker session in [languageCode].
  Future<void> startSession(String languageCode) async {
    try {
      print('🎤 [HermesController] Starting speaker session...');

      // 🎯 CRITICAL: Create fresh engines for this session
      _createFreshEngines();

      // Listen to all state changes and push them to Riverpod
      _subscription = _engine!.stream.listen((newState) {
        state = AsyncData(newState);
      });

      _isSpeakerSession = true;
      await _engine!.startSession(languageCode);

      print('✅ [HermesController] Speaker session started');
    } catch (e, stackTrace) {
      print('❌ [HermesController] Failed to start speaker session: $e');
      state = AsyncError(e, stackTrace);
      _disposeCurrentEngines();
    }
  }

  /// IMPROVED: Join an audience session with [sessionCode].
  Future<void> joinSession(String sessionCode) async {
    try {
      print('👥 [HermesController] Joining audience session...');

      // 🎯 CRITICAL: Create fresh engines for this session
      _createFreshEngines();

      // Listen to all state changes and push them to Riverpod
      _subscription = _engine!.stream.listen((newState) {
        state = AsyncData(newState);
      });

      _isSpeakerSession = false;
      await _engine!.joinSession(sessionCode);

      print('✅ [HermesController] Audience session joined');
    } catch (e, stackTrace) {
      print('❌ [HermesController] Failed to join audience session: $e');
      state = AsyncError(e, stackTrace);
      _disposeCurrentEngines();
    }
  }

  /// Pause the current session (only for speaker sessions).
  Future<void> pauseSession() async {
    if (_isSpeakerSession && _speakerEngine != null) {
      await _speakerEngine!.pause();
    }
    // Note: Audience sessions don't have pause functionality as they're passive
  }

  /// Resume the current session (only for speaker sessions).
  Future<void> resumeSession() async {
    if (_isSpeakerSession && _speakerEngine != null) {
      await _speakerEngine!.resume();
    }
    // Note: Audience sessions don't have resume functionality as they're passive
  }

  /// IMPROVED: Stop and clean up the current session.
  Future<void> stop() async {
    try {
      print('🛑 [HermesController] Stopping session...');

      if (_isSpeakerSession && _speakerEngine != null) {
        await _speakerEngine!.stop();
      }

      if (_engine != null) {
        await _engine!.stop();
      }

      // 🎯 CRITICAL: Dispose and clean up all engines
      _disposeCurrentEngines();
      _isSpeakerSession = false;

      // Return to initial state
      state = AsyncData(HermesSessionState.initial());

      print('✅ [HermesController] Session stopped and cleaned up');
    } catch (e, stackTrace) {
      print('❌ [HermesController] Error stopping session: $e');
      state = AsyncError(e, stackTrace);
      _disposeCurrentEngines();
    }
  }

  /// Whether the current session is a speaker session
  bool get isSpeakerSession => _isSpeakerSession;
}
