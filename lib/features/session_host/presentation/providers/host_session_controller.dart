// lib/features/session_host/presentation/providers/host_session_controller.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/features/session_host/domain/entities/session_info.dart';
import 'package:hermes/features/session_host/domain/usecases/start_session_usecase.dart';
import 'package:hermes/features/session_host/domain/usecases/stop_session_usecase.dart';
import 'package:hermes/features/session_host/domain/usecases/monitor_session_usecase.dart';
import 'package:hermes/core/service_locator.dart';
// ADD: Import HermesController
import 'package:hermes/core/hermes_engine/hermes_controller.dart';

/// Holds the UI state for the host session flow.
class HostSessionState {
  final bool isLoading;
  final String? sessionCode;
  final String? errorMessage;
  final SessionInfo? sessionInfo;

  const HostSessionState({
    this.isLoading = false,
    this.sessionCode,
    this.errorMessage,
    this.sessionInfo,
  });

  HostSessionState copyWith({
    bool? isLoading,
    String? sessionCode,
    String? errorMessage,
    SessionInfo? sessionInfo,
  }) {
    return HostSessionState(
      isLoading: isLoading ?? this.isLoading,
      sessionCode: sessionCode ?? this.sessionCode,
      errorMessage: errorMessage,
      sessionInfo: sessionInfo ?? this.sessionInfo,
    );
  }

  static HostSessionState initial() => const HostSessionState();
}

/// A Riverpod provider exposing [HostSessionController].
final hostSessionControllerProvider =
    StateNotifierProvider<HostSessionController, HostSessionState>((ref) {
      return HostSessionController(
        // ADD: Pass ref for HermesController access
        ref: ref,
        startSessionUc: getIt<StartSessionUseCase>(),
        stopSessionUc: getIt<StopSessionUseCase>(),
        monitorSessionUc: getIt<MonitorSessionUseCase>(),
      );
    });

/// Manages starting, monitoring, and stopping a host session.
class HostSessionController extends StateNotifier<HostSessionState> {
  // ADD: Ref for HermesController access
  final Ref _ref;
  final StartSessionUseCase _startSessionUc;
  final StopSessionUseCase _stopSessionUc;
  final MonitorSessionUseCase _monitorSessionUc;

  StreamSubscription<SessionInfo>? _monitorSub;

  HostSessionController({
    // ADD: Accept ref
    required Ref ref,
    required StartSessionUseCase startSessionUc,
    required StopSessionUseCase stopSessionUc,
    required MonitorSessionUseCase monitorSessionUc,
  }) : _ref = ref,
       _startSessionUc = startSessionUc,
       _stopSessionUc = stopSessionUc,
       _monitorSessionUc = monitorSessionUc,
       super(HostSessionState.initial());

  /// Starts a new host session in [languageCode] and begins monitoring.
  Future<void> startSession(String languageCode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // ADD: Start HermesEngine
      final hermesController = _ref.read(hermesControllerProvider.notifier);
      await hermesController.startSession(languageCode);

      final code = await _startSessionUc.execute(languageCode);
      state = state.copyWith(isLoading: false, sessionCode: code);

      // Begin listening to session updates
      _monitorSub?.cancel();
      _monitorSub = _monitorSessionUc.execute(code).listen((info) {
        state = state.copyWith(sessionInfo: info);
      });
    } catch (err) {
      state = state.copyWith(isLoading: false, errorMessage: err.toString());
    }
  }

  /// Stops the current host session and clears state.
  Future<void> stopSession() async {
    final code = state.sessionCode;
    if (code != null) {
      // ADD: Stop HermesEngine
      final hermesController = _ref.read(hermesControllerProvider.notifier);
      await hermesController.stop();

      await _stopSessionUc.execute(code);
      _monitorSub?.cancel();
      state = HostSessionState.initial();
    }
  }

  @override
  void dispose() {
    _monitorSub?.cancel();
    super.dispose();
  }
}
