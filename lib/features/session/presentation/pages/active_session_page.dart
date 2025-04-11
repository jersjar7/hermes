// lib/features/session/presentation/pages/active_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hermes/core/utils/debug_log_helper.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/domain/usecases/end_session.dart';
import 'package:hermes/features/session/presentation/controllers/active_session_controller.dart';
import 'package:hermes/features/session/presentation/pages/session_summary_page.dart';
import 'package:hermes/features/session/presentation/widgets/pre_speaking_view.dart';
import 'package:hermes/features/session/presentation/widgets/session_action_bar.dart';
import 'package:hermes/features/session/presentation/widgets/session_status_bar.dart';
import 'package:hermes/features/session/presentation/widgets/speaking_view.dart';
import 'package:hermes/features/translation/infrastructure/utils/permission_handler_util.dart';
import 'package:hermes/features/translation/presentation/controllers/speaker_controller.dart';
import 'package:hermes/features/translation/presentation/widgets/audio_diagnostic_widget.dart';
import 'package:hermes/features/translation/presentation/widgets/translation_error_message.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

/// Page for active session for speaker
class ActiveSessionPage extends StatefulWidget {
  /// The active session
  final Session session;

  /// Creates a new [ActiveSessionPage]
  const ActiveSessionPage({super.key, required this.session});

  @override
  State<ActiveSessionPage> createState() => _ActiveSessionPageState();
}

class _ActiveSessionPageState extends State<ActiveSessionPage>
    with WidgetsBindingObserver {
  late ActiveSessionController _controller;
  late PermissionHandlerUtil _permissionHandler;
  late DebugLogHelper _debugLogHelper;

  bool _showDiagnostics = false; // Toggle for showing diagnostic tools

  @override
  void initState() {
    super.initState();

    _controller = ActiveSessionController(
      speakerController: GetIt.instance<SpeakerController>(),
      endSession: GetIt.instance<EndSession>(),
      logger: GetIt.instance<Logger>(),
      session: widget.session,
    );

    _permissionHandler = PermissionHandlerUtil(GetIt.instance<Logger>());
    _debugLogHelper = DebugLogHelper(GetIt.instance<Logger>());

    // Start collecting logs for diagnostics
    _debugLogHelper.startLogging();
    _debugLogHelper.log('ActiveSessionPage initialized');
    _debugLogHelper.log('Session ID: ${widget.session.id}');
    _debugLogHelper.log('Session name: ${widget.session.name}');
    _debugLogHelper.log('System info: ${_debugLogHelper.collectSystemInfo()}');

    // Add as observer to handle app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Log lifecycle changes
    _debugLogHelper.log('App lifecycle state changed to: $state');

    // If returning to foreground, check permission again
    if (state == AppLifecycleState.resumed &&
        !_controller.hasCheckedPermission) {
      _debugLogHelper.log('Rechecking microphone permission after resuming');
      _controller.checkMicrophonePermission();
    }
  }

  @override
  void dispose() {
    _debugLogHelper.log('ActiveSessionPage disposing');
    _debugLogHelper.stopLogging();

    // Save logs before closing
    _debugLogHelper.saveLogsToFile().then((path) {
      if (path != null) {
        print('Debug logs saved to: $path');
      }
    });

    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Handle main button (start/pause/resume) press
  void _handleMainButtonPress() async {
    _debugLogHelper.log(
      'Main button pressed, isListening=${_controller.isListening}',
    );

    if (_controller.isListening) {
      _debugLogHelper.log('Toggling pause/resume');
      await _controller.togglePauseResume();
    } else {
      _debugLogHelper.log('Starting listening');
      final success = await _controller.toggleListening();
      _debugLogHelper.log('Start listening result: $success');

      if (!success && _controller.errorMessage != null) {
        _debugLogHelper.log('Error occurred: ${_controller.errorMessage}');

        if (_controller.isPermissionError && mounted) {
          _debugLogHelper.log(
            'Permission error detected, showing settings dialog',
          );
          _permissionHandler.showPermissionSettingsDialog(
            context,
            onCancel: () {
              _debugLogHelper.log('User canceled permission dialog');
            },
          );
        }
      }
    }
  }

  /// Handle end session
  void _handleEndSession() async {
    _debugLogHelper.log('End session button pressed');
    final success = await _controller.endSession();
    _debugLogHelper.log('End session result: $success');

    if (success && mounted) {
      // Calculate session duration
      final sessionDuration = _controller.getSessionDuration();
      _debugLogHelper.log('Session duration: $sessionDuration');

      // Navigate to summary page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => SessionSummaryPage(
                session: _controller.session,
                transcripts: _controller.transcripts,
                audienceCount: _controller.listenerCount,
                sessionDuration: sessionDuration,
              ),
        ),
      );
    }
  }

  /// Copy session code to clipboard
  void _copySessionCode() {
    _debugLogHelper.log('Copy session code button pressed');
    Clipboard.setData(ClipboardData(text: _controller.session.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session code copied to clipboard')),
    );
  }

  /// Handle retry after error
  void _handleRetry() async {
    _debugLogHelper.log('Retry button pressed');
    await _controller.retryAfterError();
  }

  /// Open app settings
  void _handleOpenSettings() async {
    _debugLogHelper.log('Open settings button pressed');
    await openAppSettings();
  }

  /// Toggle diagnostic view
  void _toggleDiagnosticView() {
    setState(() {
      _showDiagnostics = !_showDiagnostics;
    });
    _debugLogHelper.log('Diagnostic view toggled: $_showDiagnostics');
  }

  @override
  Widget build(BuildContext context) {
    // Get language selection from session
    final language =
        LanguageSelections.getByCode(_controller.session.sourceLanguage) ??
        LanguageSelections.english;

    // Use ChangeNotifierProvider to rebuild only when controller state changes
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<ActiveSessionController>(
        builder: (context, controller, child) {
          // Log diagnostic data
          _debugLogHelper.log(
            'State update: isListening=${controller.isListening}, '
            'isPaused=${controller.isPaused}, '
            'isInitializing=${controller.isInitializing}, '
            'viewState=${controller.viewState}',
          );

          if (controller.errorMessage != null) {
            _debugLogHelper.log('Error present: ${controller.errorMessage}');
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(controller.session.name),
              actions: [
                // Show diagnostics toggle (long press to activate)
                IconButton(
                  icon: Icon(
                    _showDiagnostics ? Icons.bug_report : Icons.info_outline,
                  ),
                  onPressed: _toggleDiagnosticView,
                  tooltip:
                      _showDiagnostics
                          ? 'Hide Diagnostics'
                          : 'Show Diagnostics',
                ),

                // Show session code in app bar for quick access
                if (controller.viewState == SessionViewState.speaking)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Code: ${controller.session.code}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _copySessionCode,
                  tooltip: 'Copy session code',
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // Top bar with consistent info
                  SessionStatusBar(
                    isListening: controller.isListening,
                    isPaused: controller.isPaused,
                    language: language,
                    listenerCount: controller.listenerCount,
                  ),

                  // Diagnostic view if enabled
                  if (_showDiagnostics)
                    AudioDiagnosticWidget(
                      hasMicPermission:
                          controller.permissionStatus?.isGranted ?? false,
                      isRecording: controller.isListening,
                      hasError: controller.errorMessage != null,
                      errorMessage: controller.errorMessage,
                      onRequestPermission: _handleOpenSettings,
                      onRetry: _handleRetry,
                    ),

                  // Error message (if any)
                  if (controller.errorMessage != null)
                    TranslationErrorMessage(
                      message: controller.errorMessage!,
                      isPermissionError: controller.isPermissionError,
                      onRetry: _handleRetry,
                      onOpenSettings:
                          controller.isPermissionError
                              ? _handleOpenSettings
                              : null,
                    ),

                  // Loading indicator during initialization
                  if (controller.isInitializing)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Initializing microphone...'),
                          ],
                        ),
                      ),
                    ),

                  // Body content based on current state
                  if (!controller.isInitializing)
                    Expanded(child: _buildMainContent(controller, language)),

                  // Bottom action bar
                  SessionActionBar(
                    isListening: controller.isListening,
                    isPaused: controller.isPaused,
                    isEnding: controller.isEnding,
                    onMainActionPressed: _handleMainButtonPress,
                    onEndSessionPressed: _handleEndSession,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(
    ActiveSessionController controller,
    LanguageSelection language,
  ) {
    switch (controller.viewState) {
      case SessionViewState.preSpeaking:
        return PreSpeakingView(
          sessionName: controller.session.name,
          sessionCode: controller.session.code,
          onCopyTap: _copySessionCode,
        );

      case SessionViewState.speaking:
        return SpeakingView(
          sessionId: controller.session.id,
          sessionName: controller.session.name,
          sessionCode: controller.session.code,
          language: language,
          showTranscription: controller.showTranscription,
          listenerCount: controller.listenerCount,
          onToggleTranscriptionVisibility:
              controller.toggleTranscriptionVisibility,
        );

      case SessionViewState.error:
        // Show a simplified view when in error state
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Microphone is not active',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please retry by tapping "Start Speaking" again.',
                  textAlign: TextAlign.center,
                ),
                if (controller.errorDetails != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      controller.errorDetails!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),

                // Add a retry button
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: ElevatedButton.icon(
                    onPressed: _handleRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
