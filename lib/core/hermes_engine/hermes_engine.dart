// lib/core/hermes_engine/hermes_engine.dart
import 'dart:async';

import 'state/hermes_session_state.dart';
import 'state/hermes_status.dart';
import 'speaker/speaker_engine.dart';
import 'audience/audience_engine.dart';
import 'usecases/playback_control.dart';
import 'buffer/countdown_timer.dart';

/// The root director that picks speaker vs. audience,
/// handles countdown, and drives playback.
class HermesEngine {
  final SpeakerEngine _speakerEngine;
  final AudienceEngine _audienceEngine;
  final PlaybackControlUseCase _playbackCtrl;
  final CountdownTimer _countdown;

  HermesSessionState _state = HermesSessionState.initial();
  final _stateController = StreamController<HermesSessionState>.broadcast();
  Stream<HermesSessionState> get stream => _stateController.stream;

  late StreamSubscription<HermesSessionState> _engineSub;

  HermesEngine({
    required SpeakerEngine speakerEngine,
    required AudienceEngine audienceEngine,
    required PlaybackControlUseCase playbackControl,
    required CountdownTimer countdown,
  }) : _speakerEngine = speakerEngine,
       _audienceEngine = audienceEngine,
       _playbackCtrl = playbackControl,
       _countdown = countdown;

  /// Starts a speaker flow: permissions, STT, translation, buffering, socket.
  Future<void> startSession(String languageCode) async {
    _emit(_state.copyWith(status: HermesStatus.buffering));

    await _speakerEngine.start(languageCode: languageCode);
    _engineSub = _speakerEngine.stream.listen(_onEngineState);
  }

  /// Starts an audience flow: join session, receive translations, buffering.
  Future<void> joinSession(String sessionCode) async {
    _emit(_state.copyWith(status: HermesStatus.buffering));

    await _audienceEngine.start(sessionCode: sessionCode);
    _engineSub = _audienceEngine.stream.listen(_onEngineState);
  }

  void _onEngineState(HermesSessionState s) {
    _state = s;
    _stateController.add(s);

    // Kick off countdown when buffer is ready
    if (s.status == HermesStatus.countdown && s.countdownSeconds != null) {
      _startCountdown(s.countdownSeconds!);
    }
  }

  void _startCountdown(int seconds) {
    _countdown.stop();
    _countdown.onTick = (remaining) {
      _emit(
        _state.copyWith(
          status: HermesStatus.countdown,
          countdownSeconds: remaining,
        ),
      );
    };
    _countdown.onComplete = _startPlayback;
    _countdown.start(seconds);
  }

  void _startPlayback() {
    _playbackCtrl.execute(
      onSegmentDone: (_) {
        _emit(_state.copyWith(status: HermesStatus.speaking));
      },
      onBufferEmpty: (_) {
        _emit(_state.copyWith(status: HermesStatus.paused));
      },
    );
  }

  void _emit(HermesSessionState newState) {
    _stateController.add(newState);
  }

  /// Stops everything and disposes streams/timers.
  Future<void> stop() async {
    await _engineSub.cancel();
    _countdown.stop();
    await _stateController.close();
  }
}
