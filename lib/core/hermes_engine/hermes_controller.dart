import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_engine.dart';
import 'package:hermes/core/hermes_engine/state/hermes_session_state.dart';
import 'package:hermes/core/service_locator.dart';

final hermesControllerProvider =
    AsyncNotifierProvider<HermesController, HermesSessionState>(
      HermesController.new,
    );

class HermesController extends AsyncNotifier<HermesSessionState> {
  late final HermesEngine _engine;
  StreamSubscription<HermesSessionState>? _subscription;

  @override
  Future<HermesSessionState> build() async {
    _engine = HermesEngine(
      stt: getIt(),
      translator: getIt(),
      tts: getIt(),
      socket: getIt(),
      session: getIt(),
      logger: getIt(),
      permission: getIt(),
      connectivity: getIt(),
    );

    _subscription = _engine.stateStream.listen((s) {
      state = AsyncData(s);
    });

    // Register cleanup logic
    ref.onDispose(() {
      _subscription?.cancel();
    });

    return _engine.currentState;
  }

  Future<void> start(String targetLang) => _engine.startSession(targetLang);
  Future<void> stop() => _engine.stopSession();
}
