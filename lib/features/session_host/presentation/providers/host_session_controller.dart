// lib/features/session_host/presentation/providers/host_session_controller.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/features/session_host/domain/entities/session_info.dart';
import 'package:hermes/features/session_host/domain/usecases/start_session_usecase.dart';
import 'package:hermes/features/session_host/domain/usecases/stop_session_usecase.dart';
import 'package:hermes/features/session_host/domain/usecases/monitor_session_usecase.dart';
import 'package:hermes/core/service_locator.dart';

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
        startSessionUc: getIt<StartSessionUseCase>(),
        stopSessionUc: getIt<StopSessionUseCase>(),
        monitorSessionUc: getIt<MonitorSessionUseCase>(),
      );
    });

/// Manages starting, monitoring, and stopping a host session.
class HostSessionController extends StateNotifier<HostSessionState> {
  final StartSessionUseCase _startSessionUc;
  final StopSessionUseCase _stopSessionUc;
  final MonitorSessionUseCase _monitorSessionUc;

  StreamSubscription<SessionInfo>? _monitorSub;

  HostSessionController({
    required StartSessionUseCase startSessionUc,
    required StopSessionUseCase stopSessionUc,
    required MonitorSessionUseCase monitorSessionUc,
  }) : _startSessionUc = startSessionUc,
       _stopSessionUc = stopSessionUc,
       _monitorSessionUc = monitorSessionUc,
       super(HostSessionState.initial());

  /// Starts a new host session in [languageCode] and begins monitoring.
  Future<void> startSession(String languageCode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
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
