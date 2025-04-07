// lib/features/session/presentation/pages/join_session_page.dart

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hermes/core/utils/extensions.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/session/domain/entities/user.dart';
import 'package:hermes/features/session/domain/usecases/join_session.dart';
import 'package:hermes/features/session/infrastructure/services/auth_service.dart';
import 'package:hermes/features/session/presentation/widgets/join_form.dart';
import 'package:hermes/features/session/presentation/widgets/qr_scanner_view.dart';
import 'package:hermes/routes.dart';

/// Page for audience to join a session
class JoinSessionPage extends StatefulWidget {
  /// Creates a new [JoinSessionPage]
  const JoinSessionPage({super.key});

  @override
  State<JoinSessionPage> createState() => _JoinSessionPageState();
}

class _JoinSessionPageState extends State<JoinSessionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isJoining = false;
  String? _errorMessage;

  final _authService = GetIt.instance<AuthService>();
  final _joinSession = GetIt.instance<JoinSession>();
  final _codeController = TextEditingController();

  LanguageSelection _selectedLanguage = LanguageSelections.english;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoinSession(String code) async {
    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      // Ensure user is signed in
      final user =
          _authService.currentUser ?? await _authService.signInAnonymously();

      // Update user role to audience
      await _authService.updateUserRole(UserRole.audience);

      // Update user preferred language
      await _authService.updatePreferredLanguage(
        _selectedLanguage.languageCode,
      );

      // Join the session
      final params = JoinSessionParams(sessionCode: code, userId: user.id);

      final result = await _joinSession(params);

      if (mounted) {
        result.fold(
          (failure) {
            setState(() {
              _errorMessage = failure.message;
              _isJoining = false;
            });
          },
          (session) {
            // Navigate to audience view
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.audienceView,
              arguments: {'session': session, 'language': _selectedLanguage},
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isJoining = false;
        });
      }
    }
  }

  void _onLanguageChanged(LanguageSelection language) {
    setState(() {
      _selectedLanguage = language;
    });
  }

  void _onQrCodeDetected(String code) {
    // Extract code from QR data
    // The format should match what we used in QrCodeDisplay
    // e.g., "hermes://join?code=happy-tiger"

    if (code.startsWith('hermes://join?code=')) {
      final sessionCode = code.substring('hermes://join?code='.length);
      _handleJoinSession(sessionCode);
    } else {
      // Try to use the raw code (in case it's just the session code)
      _handleJoinSession(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a Session'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.keyboard), text: 'Enter Code'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
          ],
        ),
      ),
      body:
          _isJoining
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Joining session...'),
                  ],
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  // Enter Code Tab
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
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

                          // Join form
                          JoinForm(
                            controller: _codeController,
                            selectedLanguage: _selectedLanguage,
                            onLanguageChanged: _onLanguageChanged,
                            onSubmit: (code) => _handleJoinSession(code),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Scan QR Tab
                  QrScannerView(
                    onCodeDetected: _onQrCodeDetected,
                    selectedLanguage: _selectedLanguage,
                    onLanguageChanged: _onLanguageChanged,
                    errorMessage: _errorMessage,
                  ),
                ],
              ),
    );
  }
}
