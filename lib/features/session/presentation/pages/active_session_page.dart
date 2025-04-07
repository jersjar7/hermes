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
import 'package:hermes/routes.dart';

/// Page for active session for speaker
class ActiveSessionPage extends StatefulWidget {
  /// The active session
  final Session session;

  /// Creates a new [ActiveSessionPage]
  const ActiveSessionPage({super.key, required this.session});

  @override
  State<ActiveSessionPage> createState() => _ActiveSessionPageState();
}

class _ActiveSessionPageState extends State<ActiveSessionPage> {
  bool _isListening = false;
  bool _isEnding = false;
  String? _errorMessage;
  int _listenerCount = 0;

  final _endSession = GetIt.instance<EndSession>();
  late Session _session;
  late StreamSubscription? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _listenerCount = _session.listeners.length;
    _setupSessionListener();
  }

  void _setupSessionListener() {
    // In a real implementation, you would subscribe to session updates
    // and update the UI when listeners join/leave
    // This would be implemented in the repository

    // For now, we'll simulate some listeners joining
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _listenerCount = _session.listeners.length;
        });
      }
    });
  }

  Future<void> _handleEndSession() async {
    setState(() {
      _isEnding = true;
      _errorMessage = null;
    });

    try {
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

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
    });

    // In a real implementation, you would start/stop the speech recognition
    // This would connect to the translation feature
    if (_isListening) {
      // Start listening
      // ...
    } else {
      // Stop listening
      // ...
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
    _sessionSubscription?.cancel();
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
              child: SingleChildScrollView(
                child: Padding(
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

                      const SizedBox(height: 32),

                      // Session code card
                      SessionCodeCard(
                        sessionCode: _session.code,
                        onCopyTap: _copySessionCode,
                      ),

                      const SizedBox(height: 32),

                      // QR code
                      QrCodeDisplay(sessionCode: _session.code),

                      const SizedBox(height: 24),

                      Text(
                        'Share this code or QR with your audience',
                        style: context.textTheme.bodyLarge,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'They can join by scanning the QR code or entering the session code in the app',
                        style: context.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // Error message (if any)
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 16),
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
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
