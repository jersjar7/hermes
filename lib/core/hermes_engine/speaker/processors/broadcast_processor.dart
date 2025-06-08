// lib/core/hermes_engine/speaker/processors/broadcast_processor.dart
// Translation broadcasting and socket communication

import 'dart:async';

import 'package:hermes/core/hermes_engine/utils/log.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/logger/logger_service.dart';

import '../config/speaker_config.dart';
import '../handlers/audience_handler.dart';

/// Broadcast processing events
abstract class BroadcastEvent {}

/// Broadcast started
class BroadcastStartedEvent extends BroadcastEvent {
  final String translatedText;
  final String targetLanguage;
  final int audienceCount;

  BroadcastStartedEvent(
    this.translatedText,
    this.targetLanguage,
    this.audienceCount,
  );
}

/// Broadcast completed successfully
class BroadcastCompletedEvent extends BroadcastEvent {
  final BroadcastResult result;

  BroadcastCompletedEvent(this.result);
}

/// Broadcast failed
class BroadcastFailedEvent extends BroadcastEvent {
  final String translatedText;
  final String targetLanguage;
  final Exception error;
  final Duration attemptDuration;

  BroadcastFailedEvent(
    this.translatedText,
    this.targetLanguage,
    this.error,
    this.attemptDuration,
  );
}

/// Audience state changed
class AudienceStateChangedEvent extends BroadcastEvent {
  final AudienceInfo audienceInfo;

  AudienceStateChangedEvent(this.audienceInfo);
}

/// Result of a broadcast operation
class BroadcastResult {
  /// The translated text that was broadcasted
  final String translatedText;

  /// Target language code
  final String targetLanguage;

  /// Number of audience members at broadcast time
  final int audienceCount;

  /// Time taken to complete the broadcast
  final Duration broadcastLatency;

  /// Session ID used for the broadcast
  final String sessionId;

  /// Whether the broadcast was successful
  final bool successful;

  /// Timestamp when broadcast was sent
  final DateTime timestamp;

  const BroadcastResult({
    required this.translatedText,
    required this.targetLanguage,
    required this.audienceCount,
    required this.broadcastLatency,
    required this.sessionId,
    required this.successful,
    required this.timestamp,
  });

  /// Whether this was a broadcast to an active audience
  bool get hadAudience => audienceCount > 0;

  /// Broadcast efficiency score (0.0 to 1.0)
  double get efficiency {
    const maxOptimalLatency = Duration(milliseconds: 500);
    if (broadcastLatency >= maxOptimalLatency) return 0.0;
    return 1.0 -
        (broadcastLatency.inMilliseconds / maxOptimalLatency.inMilliseconds);
  }
}

/// Broadcast delivery status
enum BroadcastStatus {
  /// Ready to broadcast
  ready,

  /// Currently broadcasting
  broadcasting,

  /// Broadcast completed successfully
  completed,

  /// Broadcast failed
  failed,

  /// No session available for broadcasting
  noSession,

  /// No audience to broadcast to
  noAudience,
}

/// Extension methods for BroadcastStatus
extension BroadcastStatusExtension on BroadcastStatus {
  /// Human-readable description
  String get description {
    switch (this) {
      case BroadcastStatus.ready:
        return 'Ready';
      case BroadcastStatus.broadcasting:
        return 'Broadcasting';
      case BroadcastStatus.completed:
        return 'Completed';
      case BroadcastStatus.failed:
        return 'Failed';
      case BroadcastStatus.noSession:
        return 'No Session';
      case BroadcastStatus.noAudience:
        return 'No Audience';
    }
  }

  /// Whether broadcasting is currently active
  bool get isActive => this == BroadcastStatus.broadcasting;

  /// Whether ready to perform new broadcast
  bool get canBroadcast =>
      this == BroadcastStatus.ready ||
      this == BroadcastStatus.completed ||
      this == BroadcastStatus.failed;
}

/// Handles translation broadcasting and socket communication
class BroadcastProcessor {
  /// Socket service for communication
  final ISocketService _socket;

  /// Session service for session management
  final ISessionService _session;

  /// Audience handler for audience tracking
  final AudienceHandler _audienceHandler;

  /// Logger for debugging and monitoring
  final HermesLogger _log;

  /// Stream controller for broadcast events
  final StreamController<BroadcastEvent> _eventController =
      StreamController<BroadcastEvent>.broadcast();

  /// Current broadcast status
  BroadcastStatus _currentStatus = BroadcastStatus.ready;

  /// Subscription to audience updates
  StreamSubscription<AudienceInfo>? _audienceSubscription;

  /// Broadcast statistics
  int _totalBroadcasts = 0;
  int _successfulBroadcasts = 0;
  int _failedBroadcasts = 0;
  Duration _totalBroadcastLatency = Duration.zero;
  DateTime? _lastBroadcastTime;

  BroadcastProcessor({
    required ISocketService socket,
    required ISessionService session,
    required AudienceHandler audienceHandler,
    required ILoggerService logger,
  }) : _socket = socket,
       _session = session,
       _audienceHandler = audienceHandler,
       _log = HermesLogger(logger, 'BroadcastProcessor') {
    _initializeAudienceTracking();
  }

  /// Stream of broadcast events
  Stream<BroadcastEvent> get events => _eventController.stream;

  /// Current broadcast status
  BroadcastStatus get currentStatus => _currentStatus;

  /// Current audience count
  int get audienceCount => _audienceHandler.audienceCount;

  /// Whether there's an active audience to broadcast to
  bool get hasAudience => _audienceHandler.currentAudience.hasAudience;

  /// Whether broadcasting is currently possible
  bool get canBroadcast => _currentStatus.canBroadcast && _hasValidSession();

  /// Initializes audience tracking
  void _initializeAudienceTracking() {
    _audienceSubscription = _audienceHandler.audienceStream.listen(
      (audienceInfo) {
        print(
          '👥 [BroadcastProcessor] Audience update: ${audienceInfo.totalListeners} listeners',
        );
        _emitEvent(AudienceStateChangedEvent(audienceInfo));
      },
      onError: (error) {
        print('❌ [BroadcastProcessor] Audience stream error: $error');
        _log.error('Audience stream error', error: error, tag: 'AudienceError');
      },
    );
  }

  /// Broadcasts translated text to the audience
  Future<BroadcastResult?> broadcastTranslation({
    required String translatedText,
    required String targetLanguage,
  }) async {
    if (!canBroadcast) {
      print(
        '🚫 [BroadcastProcessor] Cannot broadcast - status: ${_currentStatus.description}',
      );
      return null;
    }

    if (!SpeakerConfig.isTextLengthValid(translatedText)) {
      print('🚫 [BroadcastProcessor] Cannot broadcast empty text');
      return null;
    }

    final sessionId = _session.currentSession?.sessionId;
    if (sessionId == null) {
      print('❌ [BroadcastProcessor] Cannot broadcast - no active session');
      _setStatus(BroadcastStatus.noSession);
      return null;
    }

    final currentAudienceCount = audienceCount;
    final broadcastStart = DateTime.now();

    print(
      '📡 [BroadcastProcessor] Broadcasting to $currentAudienceCount listeners: "${_previewText(translatedText)}"',
    );

    _setStatus(BroadcastStatus.broadcasting);
    _emitEvent(
      BroadcastStartedEvent(
        translatedText,
        targetLanguage,
        currentAudienceCount,
      ),
    );

    try {
      // Create translation event
      final event = TranslationEvent(
        sessionId: sessionId,
        translatedText: translatedText,
        targetLanguage: targetLanguage,
      );

      // Send to socket with timeout
      await _socket.send(event).timeout(SpeakerConfig.socketDisconnectTimeout);

      final broadcastLatency = DateTime.now().difference(broadcastStart);

      // Create successful result
      final result = BroadcastResult(
        translatedText: translatedText,
        targetLanguage: targetLanguage,
        audienceCount: currentAudienceCount,
        broadcastLatency: broadcastLatency,
        sessionId: sessionId,
        successful: true,
        timestamp: DateTime.now(),
      );

      // Update statistics
      _totalBroadcasts++;
      _successfulBroadcasts++;
      _totalBroadcastLatency += broadcastLatency;
      _lastBroadcastTime = DateTime.now();

      _setStatus(BroadcastStatus.completed);

      print(
        '✅ [BroadcastProcessor] Broadcast completed in ${broadcastLatency.inMilliseconds}ms',
      );
      print('   Text: "${_previewText(translatedText)}"');
      print('   Audience: $currentAudienceCount listeners');

      _log.info(
        'Translation broadcasted successfully: "${_previewText(translatedText)}" to $currentAudienceCount listeners (${broadcastLatency.inMilliseconds}ms)',
        tag: 'BroadcastSuccess',
      );

      _emitEvent(BroadcastCompletedEvent(result));

      // Reset to ready for next broadcast
      _setStatus(BroadcastStatus.ready);

      return result;
    } catch (e, stackTrace) {
      final broadcastLatency = DateTime.now().difference(broadcastStart);

      print(
        '❌ [BroadcastProcessor] Broadcast failed after ${broadcastLatency.inMilliseconds}ms: $e',
      );

      _log.error(
        'Broadcast failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'BroadcastError',
      );

      // Update failure statistics
      _totalBroadcasts++;
      _failedBroadcasts++;
      _totalBroadcastLatency += broadcastLatency;

      _setStatus(BroadcastStatus.failed);
      _emitEvent(
        BroadcastFailedEvent(
          translatedText,
          targetLanguage,
          Exception(e.toString()),
          broadcastLatency,
        ),
      );

      // Reset to ready after brief delay
      Timer(const Duration(seconds: 1), () {
        if (_currentStatus == BroadcastStatus.failed) {
          _setStatus(BroadcastStatus.ready);
        }
      });

      throw Exception('Failed to broadcast translation: $e');
    }
  }

  /// Handles incoming socket events
  void handleSocketEvent(SocketEvent event) {
    // Delegate audience-related events to audience handler
    _audienceHandler.handleSocketEvent(event);

    // Handle broadcast-specific events if needed
    // Additional event handling can be added here as needed
  }

  /// Checks if there's a valid session for broadcasting
  bool _hasValidSession() {
    final session = _session.currentSession;
    return session != null && session.sessionId.isNotEmpty;
  }

  /// Sets current broadcast status
  void _setStatus(BroadcastStatus newStatus) {
    if (_currentStatus != newStatus) {
      final previousStatus = _currentStatus;
      _currentStatus = newStatus;

      print(
        '🔄 [BroadcastProcessor] Status changed: ${previousStatus.description} → ${newStatus.description}',
      );
    }
  }

  /// Emits a broadcast event
  void _emitEvent(BroadcastEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Creates preview of text for logging
  String _previewText(String text) {
    if (text.length <= SpeakerConfig.debugTextPreviewLength) {
      return text;
    }
    return '${text.substring(0, SpeakerConfig.debugTextPreviewLength)}...';
  }

  /// Gets comprehensive broadcast statistics
  Map<String, dynamic> getBroadcastStats() {
    final successRate =
        _totalBroadcasts > 0
            ? (_successfulBroadcasts / _totalBroadcasts) * 100.0
            : 0.0;

    final avgBroadcastLatency =
        _successfulBroadcasts > 0
            ? _totalBroadcastLatency.inMilliseconds / _successfulBroadcasts
            : 0.0;

    return {
      'currentStatus': _currentStatus.description,
      'canBroadcast': canBroadcast,
      'hasAudience': hasAudience,
      'audienceCount': audienceCount,
      'totalBroadcasts': _totalBroadcasts,
      'successfulBroadcasts': _successfulBroadcasts,
      'failedBroadcasts': _failedBroadcasts,
      'successRate': successRate,
      'avgBroadcastLatency': avgBroadcastLatency,
      'lastBroadcastTime': _lastBroadcastTime?.toIso8601String(),
      'hasValidSession': _hasValidSession(),
      'audienceStats': _audienceHandler.getAudienceStats(),
    };
  }

  /// Resets broadcast statistics
  void resetStats() {
    print('🔄 [BroadcastProcessor] Resetting broadcast statistics');

    _totalBroadcasts = 0;
    _successfulBroadcasts = 0;
    _failedBroadcasts = 0;
    _totalBroadcastLatency = Duration.zero;
    _lastBroadcastTime = null;
  }

  /// Forces processor to ready state
  void forceReset() {
    print('🔄 [BroadcastProcessor] Force resetting broadcast processor');
    _setStatus(BroadcastStatus.ready);
  }

  /// Tests socket connectivity for broadcasting
  Future<bool> testConnectivity() async {
    try {
      print('🔍 [BroadcastProcessor] Testing socket connectivity...');

      // Simple connectivity test - this would depend on your socket implementation
      // For now, we'll check if socket is connected
      final isConnected = _socket.isConnected;

      print(
        '${isConnected ? '✅' : '❌'} [BroadcastProcessor] Socket connectivity: ${isConnected ? 'Connected' : 'Disconnected'}',
      );

      return isConnected;
    } catch (e) {
      print('❌ [BroadcastProcessor] Connectivity test failed: $e');
      return false;
    }
  }

  /// Disposes of resources
  void dispose() {
    print('🗑️ [BroadcastProcessor] Disposing broadcast processor...');

    _audienceSubscription?.cancel();
    _audienceSubscription = null;

    if (!_eventController.isClosed) {
      _eventController.close();
    }

    print('✅ [BroadcastProcessor] Broadcast processor disposed');
  }
}
