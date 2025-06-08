// lib/core/hermes_engine/speaker/handlers/audience_handler.dart
// Audience count and language distribution management

import 'dart:async';

import 'package:hermes/core/hermes_engine/utils/log.dart';
import 'package:hermes/core/services/socket/socket_event.dart';
import 'package:hermes/core/services/logger/logger_service.dart';

import '../config/speaker_config.dart';

/// Audience statistics and information
class AudienceInfo {
  /// Total number of active listeners
  final int totalListeners;

  /// Distribution of listeners by language preference
  final Map<String, int> languageDistribution;

  /// Timestamp when this info was last updated
  final DateTime lastUpdated;

  /// List of recently joined user IDs (for tracking)
  final List<String> recentJoins;

  /// List of recently left user IDs (for tracking)
  final List<String> recentLeaves;

  const AudienceInfo({
    required this.totalListeners,
    required this.languageDistribution,
    required this.lastUpdated,
    this.recentJoins = const [],
    this.recentLeaves = const [],
  });

  /// Creates initial empty audience info
  factory AudienceInfo.empty() {
    return AudienceInfo(
      totalListeners: SpeakerConfig.defaultAudienceCount,
      languageDistribution: const {},
      lastUpdated: DateTime.now(),
    );
  }

  /// Creates updated audience info with new values
  AudienceInfo copyWith({
    int? totalListeners,
    Map<String, int>? languageDistribution,
    DateTime? lastUpdated,
    List<String>? recentJoins,
    List<String>? recentLeaves,
  }) {
    return AudienceInfo(
      totalListeners: totalListeners ?? this.totalListeners,
      languageDistribution: languageDistribution ?? this.languageDistribution,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      recentJoins: recentJoins ?? this.recentJoins,
      recentLeaves: recentLeaves ?? this.recentLeaves,
    );
  }

  /// Whether there are active listeners
  bool get hasAudience => totalListeners > 0;

  /// Number of different languages in the audience
  int get languageCount => languageDistribution.keys.length;

  /// Most popular language among listeners
  String? get dominantLanguage {
    if (languageDistribution.isEmpty) return null;

    String? dominant;
    int maxCount = 0;

    for (final entry in languageDistribution.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominant = entry.key;
      }
    }

    return dominant;
  }

  /// Percentage of audience using the dominant language
  double get dominantLanguagePercentage {
    if (!hasAudience || dominantLanguage == null) return 0.0;
    final dominantCount = languageDistribution[dominantLanguage] ?? 0;
    return (dominantCount / totalListeners) * 100.0;
  }

  @override
  String toString() {
    return 'AudienceInfo{'
        'listeners: $totalListeners, '
        'languages: $languageCount, '
        'dominant: $dominantLanguage (${dominantLanguagePercentage.toStringAsFixed(1)}%)'
        '}';
  }
}

/// Handles audience tracking and management for speaker sessions
class AudienceHandler {
  /// Stream controller for audience updates
  final StreamController<AudienceInfo> _audienceController =
      StreamController<AudienceInfo>.broadcast();

  /// Current audience information
  AudienceInfo _currentAudience = AudienceInfo.empty();

  /// Logger for debugging and monitoring
  final HermesLogger _log;

  /// Recent activity tracking (for debugging and analytics)
  final List<String> _recentJoins = <String>[];
  final List<String> _recentLeaves = <String>[];

  AudienceHandler({required ILoggerService logger})
    : _log = HermesLogger(logger);

  /// Stream of audience updates
  Stream<AudienceInfo> get audienceStream => _audienceController.stream;

  /// Current audience information
  AudienceInfo get currentAudience => _currentAudience;

  /// Current audience count
  int get audienceCount => _currentAudience.totalListeners;

  /// Current language distribution
  Map<String, int> get languageDistribution =>
      Map.unmodifiable(_currentAudience.languageDistribution);

  /// Handles incoming socket events related to audience
  void handleSocketEvent(SocketEvent event) {
    if (event is AudienceUpdateEvent) {
      _handleAudienceUpdate(event);
    } else if (event is SessionJoinEvent) {
      _handleUserJoin(event);
    } else if (event is SessionLeaveEvent) {
      _handleUserLeave(event);
    }
  }

  /// Processes audience update events from the socket
  void _handleAudienceUpdate(AudienceUpdateEvent event) {
    print(
      '👥 [AudienceHandler] Audience update: ${event.totalListeners} listeners',
    );
    print('   Languages: ${event.languageDistribution}');

    // Validate the language distribution doesn't exceed limits
    final limitedDistribution = _limitLanguageDistribution(
      event.languageDistribution,
    );

    final previousCount = _currentAudience.totalListeners;
    final newInfo = AudienceInfo(
      totalListeners: event.totalListeners,
      languageDistribution: limitedDistribution,
      lastUpdated: DateTime.now(),
      recentJoins: List.from(_recentJoins),
      recentLeaves: List.from(_recentLeaves),
    );

    _currentAudience = newInfo;

    // Log significant changes
    if (event.totalListeners != previousCount) {
      final change = event.totalListeners - previousCount;
      final direction = change > 0 ? 'increased' : 'decreased';
      print(
        '📊 [AudienceHandler] Audience $direction by ${change.abs()} ($previousCount → ${event.totalListeners})',
      );
    }

    // Clear recent activity after including in update
    _clearRecentActivity();

    // Emit update
    _emitAudienceUpdate(newInfo);

    // Log analytics
    _logAudienceAnalytics(newInfo);
  }

  /// Handles individual user join events
  void _handleUserJoin(SessionJoinEvent event) {
    print(
      '👋 [AudienceHandler] User joined: ${event.userId} (${event.language})',
    );

    // Track recent join
    _recentJoins.add(event.userId);
    _trimRecentActivity();

    _log.info(
      'User joined session: ${event.userId} (${event.language}) - Total audience: ${_currentAudience.totalListeners}',
      tag: 'UserJoin',
    );
  }

  /// Handles individual user leave events
  void _handleUserLeave(SessionLeaveEvent event) {
    print('👋 [AudienceHandler] User left: ${event.userId}');

    // Track recent leave
    _recentLeaves.add(event.userId);
    _trimRecentActivity();

    _log.info(
      'User left session: ${event.userId} - Total audience: ${_currentAudience.totalListeners}',
      tag: 'UserLeave',
    );
  }

  /// Limits language distribution map to prevent memory issues
  Map<String, int> _limitLanguageDistribution(Map<String, int> distribution) {
    if (distribution.length <= SpeakerConfig.maxLanguageDistributions) {
      return Map.from(distribution);
    }

    print(
      '⚠️ [AudienceHandler] Limiting language distribution (${distribution.length} → ${SpeakerConfig.maxLanguageDistributions})',
    );

    // Keep only the top languages by listener count
    final sortedEntries =
        distribution.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final limitedEntries = sortedEntries.take(
      SpeakerConfig.maxLanguageDistributions,
    );
    return Map.fromEntries(limitedEntries);
  }

  /// Trims recent activity lists to prevent memory buildup
  void _trimRecentActivity() {
    const maxRecentItems = 20;

    if (_recentJoins.length > maxRecentItems) {
      _recentJoins.removeRange(0, _recentJoins.length - maxRecentItems);
    }

    if (_recentLeaves.length > maxRecentItems) {
      _recentLeaves.removeRange(0, _recentLeaves.length - maxRecentItems);
    }
  }

  /// Clears recent activity tracking
  void _clearRecentActivity() {
    _recentJoins.clear();
    _recentLeaves.clear();
  }

  /// Emits audience update to listeners
  void _emitAudienceUpdate(AudienceInfo info) {
    if (!_audienceController.isClosed) {
      _audienceController.add(info);
      print(
        '📡 [AudienceHandler] Emitted audience update: ${info.totalListeners} listeners',
      );
    } else {
      print('⚠️ [AudienceHandler] Cannot emit - controller closed');
    }
  }

  /// Logs audience analytics and insights
  void _logAudienceAnalytics(AudienceInfo info) {
    if (!info.hasAudience) return;

    final analyticsMessage =
        'Audience analytics: '
        '${info.totalListeners} listeners, '
        '${info.languageCount} languages, '
        'dominant: ${info.dominantLanguage} (${info.dominantLanguagePercentage.toStringAsFixed(1)}%), '
        'distribution: ${info.languageDistribution}';

    _log.info(analyticsMessage, tag: 'Analytics');

    // Log insights for large audiences
    if (info.totalListeners >= 10) {
      print(
        '📈 [AudienceHandler] Large audience detected: ${info.totalListeners} listeners',
      );
      _log.info(
        'Large audience detected: ${info.totalListeners} listeners',
        tag: 'LargeAudience',
      );

      if (info.languageCount >= 3) {
        print(
          '🌍 [AudienceHandler] Multilingual audience: ${info.languageCount} languages',
        );
        _log.info(
          'Multilingual audience detected: ${info.languageCount} languages',
          tag: 'Multilingual',
        );
      }
    }
  }

  /// Manually updates audience count (for testing or fallback)
  void updateAudienceCount(int count) {
    print('🔧 [AudienceHandler] Manual audience count update: $count');

    final newInfo = _currentAudience.copyWith(
      totalListeners: count,
      lastUpdated: DateTime.now(),
    );

    _currentAudience = newInfo;
    _emitAudienceUpdate(newInfo);
  }

  /// Gets audience statistics for monitoring
  Map<String, dynamic> getAudienceStats() {
    final info = _currentAudience;
    return {
      'totalListeners': info.totalListeners,
      'hasAudience': info.hasAudience,
      'languageCount': info.languageCount,
      'dominantLanguage': info.dominantLanguage,
      'dominantPercentage': info.dominantLanguagePercentage,
      'lastUpdated': info.lastUpdated.toIso8601String(),
      'recentJoins': _recentJoins.length,
      'recentLeaves': _recentLeaves.length,
    };
  }

  /// Resets audience to empty state
  void reset() {
    print('🔄 [AudienceHandler] Resetting audience state');

    _currentAudience = AudienceInfo.empty();
    _clearRecentActivity();
    _emitAudienceUpdate(_currentAudience);
  }

  /// Disposes of resources and closes streams
  void dispose() {
    print('🗑️ [AudienceHandler] Disposing audience handler');

    _clearRecentActivity();

    if (!_audienceController.isClosed) {
      _audienceController.close();
    }

    print('✅ [AudienceHandler] Audience handler disposed');
  }
}
