// lib/features/session/presentation/pages/active_session_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hermes/core/utils/extensions.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/domain/usecases/end_session.dart';
import 'package:hermes/features/session/presentation/widgets/qr_code_display.dart';
import 'package:hermes/features/session/presentation/widgets/session_code_card.dart';
import 'package:hermes/features/translation/presentation/controllers/speaker_controller.dart';
import 'package:hermes/features/translation/presentation/widgets/live_transcript_view.dart';
import 'package:hermes/routes.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _isListening = false;
  bool _isEnding = false;
  String? _errorMessage;
  int _listenerCount = 0;
  bool _hasCheckedPermission = false;

  final _endSession = GetIt.instance<EndSession>();
  late Session _session;
  Timer? _listenerUpdateTimer;
  StreamSubscription? _sessionSubscription;

  final SpeakerController _speakerController =
      GetIt.instance<SpeakerController>();

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _speakerController.setActiveSession(_session);
    _listenerCount = _session.listeners.length;
    _setupListenerUpdates();

    // Add as observer to handle app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Check microphone permission on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMicrophonePermission();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If returning to foreground, check permission again
    // This helps handle the case where user grants permission in settings
    if (state == AppLifecycleState.resumed && !_hasCheckedPermission) {
      _checkMicrophonePermission();
    }
  }

  void _setupListenerUpdates() {
    // Update listener count periodically
    _listenerUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _listenerCount = _session.listeners.length;
        });
      }
    });

    // In a real implementation, you would subscribe to session updates
    // and update the UI when listeners join/leave
    // This would be implemented in the repository
  }

  Future<bool> _checkMicrophonePermission() async {
    print("[PERMISSION_DEBUG] Checking microphone permission...");

    final status = await Permission.microphone.status;
    print("[PERMISSION_DEBUG] Initial status: $status");

    if (status.isGranted) {
      print("[PERMISSION_DEBUG] Microphone already granted");
      setState(() {
        _hasCheckedPermission = true;
      });
      return true;
    }

    if (status.isPermanentlyDenied) {
      print("[PERMISSION_DEBUG] Mic permanently denied - show settings dialog");
      _showPermissionSettingsDialog();
      return false;
    }

    if (status.isDenied || status.isRestricted) {
      print("[PERMISSION_DEBUG] Requesting microphone permission now...");
      final requestResult = await Permission.microphone.request();
      print("[PERMISSION_DEBUG] Result from system dialog: $requestResult");

      setState(() {
        _hasCheckedPermission = true;
      });

      if (requestResult.isGranted) {
        print("[PERMISSION_DEBUG] Mic permission granted!");
        return true;
      }

      if (requestResult.isPermanentlyDenied) {
        print("[PERMISSION_DEBUG] Mic permanently denied AFTER request");
        _showPermissionSettingsDialog();
      } else {
        print("[PERMISSION_DEBUG] Mic permission still denied after request");
      }

      return false;
    }

    print("[PERMISSION_DEBUG] Reached unexpected state: $status");
    return false;
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Microphone Permission Required'),
          content: const Text(
            'Hermes needs microphone access to transcribe your speech. '
            'Please enable microphone permission in settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleEndSession() async {
    setState(() {
      _isEnding = true;
      _errorMessage = null;
    });

    try {
      // Stop listening if active
      if (_isListening) {
        await _speakerController.stopListening();
      }

      final params = EndSessionParams(sessionId: _session.id);
      final result = await _endSession(params);

      if (mounted) {
        result.fold(
          (failure) {
            setState(() {
              _errorMessage = failure.message;
              _isEnding = false;
            });
          },
          (session) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home,
              (route) => false,
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isEnding = false;
        });
      }
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speakerController.stopListening();
      setState(() {
        _isListening = _speakerController.isListening;
      });
    } else {
      // Check permission first
      final hasPermission = await _checkMicrophonePermission();

      if (hasPermission) {
        final success = await _speakerController.startListening();
        if (mounted) {
          setState(() {
            _isListening = _speakerController.isListening;
            _errorMessage = _speakerController.errorMessage;

            if (!success && _errorMessage != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(_errorMessage!)));
            }
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone permission is required to use this feature',
            ),
          ),
        );
      }
    }
  }

  void _copySessionCode() {
    Clipboard.setData(ClipboardData(text: _session.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session code copied to clipboard')),
    );
  }

  @override
  void dispose() {
    _listenerUpdateTimer?.cancel();
    _sessionSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get language selection from session
    final language =
        LanguageSelections.getByCode(_session.sourceLanguage) ??
        LanguageSelections.english;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Session'),
        actions: [
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
            Expanded(
              child: Column(
                children: [
                  // Session info section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Session name
                        Text(
                          _session.name,
                          style: context.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        // Session language
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(language.flagEmoji),
                            const SizedBox(width: 8),
                            Text(
                              'Speaking in ${language.englishName}',
                              style: context.textTheme.titleMedium,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Listeners count
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people),
                                const SizedBox(width: 8),
                                Text(
                                  '$_listenerCount ${_listenerCount == 1 ? 'listener' : 'listeners'}',
                                  style: context.textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Session code card
                        SessionCodeCard(
                          sessionCode: _session.code,
                          onCopyTap: _copySessionCode,
                        ),

                        const SizedBox(height: 16),

                        // QR code
                        QrCodeDisplay(sessionCode: _session.code),

                        const SizedBox(height: 8),

                        Text(
                          'Share this code or QR with your audience',
                          style: context.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                  // Transcription section
                  Expanded(
                    child: LiveTranscriptView(
                      sessionId: _session.id,
                      sourceLanguage: language,
                      targetLanguage:
                          language, // Speaker sees own language by default
                      isSpeakerView: true,
                    ),
                  ),

                  // Error message (if any)
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Microphone button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleListening,
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_off),
                      label: Text(
                        _isListening ? 'Stop Speaking' : 'Start Speaking',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isListening
                                ? Colors.red
                                : context.theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // End session button
                  ElevatedButton.icon(
                    onPressed: _isEnding ? null : _handleEndSession,
                    icon:
                        _isEnding
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.close),
                    label: const Text('End Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
