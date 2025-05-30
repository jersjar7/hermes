// lib/features/session_host/data/repositories/session_repository_impl.dart

import 'dart:async';

import 'package:hermes/features/session_host/data/datasources/session_local_datasource.dart';
import 'package:hermes/features/session_host/data/datasources/session_remote_datasource.dart';
import 'package:hermes/features/session_host/data/models/session_info_model.dart';
import 'package:hermes/features/session_host/domain/entities/session_info.dart';
import 'package:hermes/features/session_host/domain/repositories/session_repository.dart';

/// Concrete implementation of [SessionRepository], delegating to
/// remote and local data sources.
class SessionRepositoryImpl implements SessionRepository {
  final SessionRemoteDataSource _remote;
  final SessionLocalDataSource _local;

  SessionRepositoryImpl({
    required SessionRemoteDataSource remote,
    required SessionLocalDataSource local,
  }) : _remote = remote,
       _local = local;

  @override
  Future<SessionInfo> startSession(String languageCode) async {
    final SessionInfoModel model = await _remote.startSession(languageCode);
    // Cache for offline or quick resume
    await _local.cacheSession(model);
    return model.toEntity();
  }

  @override
  Future<void> stopSession(String sessionId) async {
    await _remote.stopSession(sessionId);
    // Clear any cached session
    await _local.clearCache();
  }

  @override
  Future<String> getSessionCode() async {
    // Try remote first; fall back to cache
    try {
      return await _remote.getSessionCode();
    } catch (_) {
      final cached = await _local.getCachedSession();
      if (cached != null) return cached.sessionId;
      rethrow;
    }
  }

  @override
  Stream<SessionInfo> monitorSession(String sessionId) {
    // Remote datasource gives SessionInfoModel stream
    return _remote.monitorSession(sessionId).map((model) => model.toEntity());
  }
}
