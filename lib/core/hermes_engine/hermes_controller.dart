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
  StreamSubscription<HermesSessionState>? _subscription;

  @override
  Future<HermesSessionState> build() async {
    // Construct the engine using our DI container
    final speakerEngine = getIt<SpeakerEngine>();
    final audienceEngine = getIt<AudienceEngine>();
    final playbackCtrl = getIt<PlaybackControlUseCase>();
    final countdown = getIt<CountdownTimer>();

    _engine = HermesEngine(
      speakerEngine: speakerEngine,
      audienceEngine: audienceEngine,
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

    // Return the “idle” initial state
    return HermesSessionState.initial();
  }

  /// Start a speaker session in [languageCode].
  Future<void> startSession(String languageCode) =>
      _engine.startSession(languageCode);

  /// Join an audience session with [sessionCode].
  Future<void> joinSession(String sessionCode) =>
      _engine.joinSession(sessionCode);

  /// Stop and clean up the current session.
  Future<void> stop() => _engine.stop();
}
