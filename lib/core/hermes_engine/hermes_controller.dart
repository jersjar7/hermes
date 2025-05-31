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
  late final HermesEngine _engine;
  late final SpeakerEngine _speakerEngine;
  late final AudienceEngine _audienceEngine;
  StreamSubscription<HermesSessionState>? _subscription;
  bool _isSpeakerSession = false;

  @override
  Future<HermesSessionState> build() async {
    // Construct the engine using our DI container
    _speakerEngine = getIt<SpeakerEngine>();
    _audienceEngine = getIt<AudienceEngine>();
    final playbackCtrl = getIt<PlaybackControlUseCase>();
    final countdown = getIt<CountdownTimer>();

    _engine = HermesEngine(
      speakerEngine: _speakerEngine,
      audienceEngine: _audienceEngine,
      playbackControl: playbackCtrl,
      countdown: countdown,
    );

    // Listen to all state changes and push them to Riverpod
    _subscription = _engine.stream.listen((newState) {
      state = AsyncData(newState);
    });

    // When the provider is disposed (e.g. on app exit), cancel the subscription
    ref.onDispose(() {
      _subscription?.cancel();
    });

    // Return the "idle" initial state
    return HermesSessionState.initial();
  }

  /// Start a speaker session in [languageCode].
  Future<void> startSession(String languageCode) async {
    _isSpeakerSession = true;
    await _engine.startSession(languageCode);
  }

  /// Join an audience session with [sessionCode].
  Future<void> joinSession(String sessionCode) async {
    _isSpeakerSession = false;
    await _engine.joinSession(sessionCode);
  }

  /// Pause the current session (only for speaker sessions).
  Future<void> pauseSession() async {
    if (_isSpeakerSession) {
      await _speakerEngine.pause();
    }
    // Note: Audience sessions don't have pause functionality as they're passive
  }

  /// Resume the current session (only for speaker sessions).
  Future<void> resumeSession() async {
    if (_isSpeakerSession) {
      await _speakerEngine.resume();
    }
    // Note: Audience sessions don't have resume functionality as they're passive
  }

  /// Stop and clean up the current session.
  Future<void> stop() async {
    if (_isSpeakerSession) {
      await _speakerEngine.stop();
    }
    await _engine.stop();
    _isSpeakerSession = false;
  }

  /// Whether the current session is a speaker session
  bool get isSpeakerSession => _isSpeakerSession;
}
