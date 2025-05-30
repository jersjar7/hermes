// lib/core/hermes_engine/config/hermes_config.dart

/// HermesEngine configuration constants
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Number of seconds to buffer before starting playback.
const int kInitialBufferCountdownSeconds = 8;

/// Minimum number of translated segments required before playback begins.
const int kMinBufferSegments = 3;

/// Minimum number of buffered segments to resume playback after a pause.
const int kResumeBufferThreshold = 2;

/// After buffer depletes, how many seconds before entering paused state.
const int kBufferDepletionTimeoutSeconds = 5;

/// No trailing slash!
/// Reads from .env via flutter_dotenv; crashes early if missing.
final String kWebSocketBaseUrl = dotenv.env['HERMES_WS_URL']!;
