// lib/features/translation/presentation/widgets/live_transcript_view.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/presentation/widgets/real_time_translation_widget.dart';

/// Widget for displaying live transcription
class LiveTranscriptView extends StatefulWidget {
  /// ID of the session
  final String sessionId;

  /// Source language of the speaker
  final LanguageSelection sourceLanguage;

  /// Target language for translation
  final LanguageSelection targetLanguage;

  /// Whether this is for the speaker view
  final bool isSpeakerView;

  /// Whether to show the header
  final bool showHeader;

  /// Creates a new [LiveTranscriptView]
  const LiveTranscriptView({
    super.key,
    required this.sessionId,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.isSpeakerView = false,
    this.showHeader = true,
  });

  @override
  State<LiveTranscriptView> createState() => _LiveTranscriptViewState();
}

class _LiveTranscriptViewState extends State<LiveTranscriptView> {
  String? _errorMessage;
  bool _isReconnecting = false;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    // No need to set up error listener yet since we'll handle errors directly
  }

  void _handleError(String errorMessage) {
    setState(() {
      _errorMessage = errorMessage;
    });

    // Auto-reconnect logic for certain errors
    if (errorMessage.contains("connection") ||
        errorMessage.contains("network")) {
      _attemptReconnect();
    }

    // Show a snackbar with the error
    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? "An error occurred"),
          action: SnackBarAction(label: 'Retry', onPressed: _retryConnection),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  void _attemptReconnect() {
    if (_isReconnecting) return;

    setState(() {
      _isReconnecting = true;
    });

    // Try to reconnect after a delay
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _retryConnection();
    });
  }

  void _retryConnection() {
    setState(() {
      _errorMessage = null;
      _isReconnecting = false;
    });

    // Force rebuild of the real-time translation widget
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (optional)
            if (widget.showHeader) _buildHeader(),

            // Error banner (new)
            if (_errorMessage != null) _buildErrorBanner(),

            // Reconnecting indicator (new)
            if (_isReconnecting) _buildReconnectingIndicator(),

            // Real-time translation widget (main content)
            Expanded(child: _buildTranslationWidget()),
          ],
        ),
      ),
    );
  }

  // Method to build the header
  Widget _buildHeader() {
    final headerText =
        widget.isSpeakerView ? 'Your Speech' : 'Live Translation';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey.shade200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            headerText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          Row(
            children: [
              Text(
                '${widget.sourceLanguage.flagEmoji} → ${widget.targetLanguage.flagEmoji}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build translation widget with error handling
  Widget _buildTranslationWidget() {
    // We need to modify the RealTimeTranslationWidget to accept an onError callback
    // For now, we'll use the basic widget and handle errors at this level
    return NotificationListener<ErrorNotification>(
      onNotification: (notification) {
        _handleError(notification.message);
        return true;
      },
      child: RealTimeTranslationWidget(
        sessionId: widget.sessionId,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
        showSourceText:
            widget.isSpeakerView ||
            widget.sourceLanguage.languageCode ==
                widget.targetLanguage.languageCode,
        isSpeakerView: widget.isSpeakerView,
      ),
    );
  }

  // New method to show error banner
  Widget _buildErrorBanner() {
    return Container(
      color: Colors.red.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? "An error occurred",
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _retryConnection,
            tooltip: 'Retry',
            color: Colors.red.shade800,
          ),
        ],
      ),
    );
  }

  // New method to show reconnecting indicator
  Widget _buildReconnectingIndicator() {
    return Container(
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(width: 8),
          const Text("Reconnecting...", style: TextStyle(color: Colors.amber)),
        ],
      ),
    );
  }
}

// Custom notification for error handling
class ErrorNotification extends Notification {
  final String message;

  ErrorNotification(this.message);
}
