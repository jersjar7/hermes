// lib/features/session_host/presentation/providers/host_session_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hermes/core/services/session/session_service.dart';

class HostSessionState {
  final bool isLoading;
  final String? sessionCode;
  final String? error;

  HostSessionState({this.isLoading = false, this.sessionCode, this.error});

  HostSessionState copyWith({
    bool? isLoading,
    String? sessionCode,
    String? error,
  }) => HostSessionState(
    isLoading: isLoading ?? this.isLoading,
    sessionCode: sessionCode ?? this.sessionCode,
    error: error ?? this.error,
  );
}

class HostSessionController extends StateNotifier<HostSessionState> {
  HostSessionController() : super(HostSessionState());

  final _sessionService = GetIt.I<ISessionService>();

  /// Initiates a new Hermes session for the given language code
  Future<void> startSession(String languageCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // use named parameter
      await _sessionService.startSession(languageCode: languageCode);

      // pull the code out of the service’s currentSession
      final code = _sessionService.currentSession?.sessionId;

      state = state.copyWith(isLoading: false, sessionCode: code);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final hostSessionControllerProvider =
    StateNotifierProvider<HostSessionController, HostSessionState>(
      (ref) => HostSessionController(),
    );
