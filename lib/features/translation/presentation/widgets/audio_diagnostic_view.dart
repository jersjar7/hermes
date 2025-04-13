// lib/features/translation/presentation/widgets/audio_diagnostic_view.dart

import 'package:flutter/material.dart';
import 'package:hermes/features/translation/presentation/widgets/enhanced_audio_level_indicator.dart';
import 'package:permission_handler/permission_handler.dart';

/// A comprehensive diagnostics widget for audio and STT debugging
class AudioDiagnosticView extends StatefulWidget {
  /// Whether microphone permission is granted
  final bool hasMicPermission;

  /// Whether currently recording
  final bool isRecording;

  /// Whether listening is paused
  final bool isPaused;

  /// Whether there was an error
  final bool hasError;

  /// Error message, if any
  final String? errorMessage;

  /// Number of transcripts received
  final int transcriptCount;

  /// Time since streaming started in milliseconds
  final int streamTimeMs;

  /// STT API status (connected, disconnected, initializing)
  final String apiStatus;

  /// Callback to request permissions
  final VoidCallback? onRequestPermission;

  /// Callback to retry recording
  final VoidCallback? onRetry;

  /// Callback to test microphone
  final Future<bool> Function()? onTestMicrophone;

  /// Callback to test API connection
  final Future<bool> Function()? onTestApiConnection;

  /// Creates a new [AudioDiagnosticView]
  const AudioDiagnosticView({
    super.key,
    required this.hasMicPermission,
    required this.isRecording,
    required this.isPaused,
    this.hasError = false,
    this.errorMessage,
    this.transcriptCount = 0,
    this.streamTimeMs = 0,
    this.apiStatus = "Unknown",
    this.onRequestPermission,
    this.onRetry,
    this.onTestMicrophone,
    this.onTestApiConnection,
  });

  @override
  State<AudioDiagnosticView> createState() => _AudioDiagnosticViewState();
}

class _AudioDiagnosticViewState extends State<AudioDiagnosticView> {
  bool _isTesting = false;
  String? _testResult;
  bool _showAdvanced = false;
  PermissionStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    final status = await Permission.microphone.status;
    if (mounted) {
      setState(() {
        _permissionStatus = status;
      });
    }
  }

  Future<void> _runMicrophoneTest() async {
    if (widget.onTestMicrophone == null) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final success = await widget.onTestMicrophone!();
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult =
              success ? "Microphone test PASSED" : "Microphone test FAILED";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = "Test error: $e";
        });
      }
    }
  }

  Future<void> _runApiTest() async {
    if (widget.onTestApiConnection == null) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final success = await widget.onTestApiConnection!();
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult =
              success
                  ? "API connection test PASSED"
                  : "API connection test FAILED";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = "API test error: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Audio Diagnostics',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: Icon(
                    _showAdvanced
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  onPressed: () {
                    setState(() {
                      _showAdvanced = !_showAdvanced;
                    });
                  },
                  tooltip: _showAdvanced ? 'Show less' : 'Show more',
                ),
              ],
            ),
            const Divider(),

            // Enhanced audio level indicator
            if (widget.isRecording)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: EnhancedAudioLevelIndicator(
                  isListening: widget.isRecording && !widget.isPaused,
                  showDebugInfo: _showAdvanced,
                  height: 40,
                ),
              ),

            // Microphone permission status
            Row(
              children: [
                Icon(
                  widget.hasMicPermission ? Icons.mic : Icons.mic_off,
                  color: widget.hasMicPermission ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Microphone Permission: ${_getPermissionStatusText()}',
                    style: TextStyle(
                      color:
                          widget.hasMicPermission ? Colors.black : Colors.red,
                    ),
                  ),
                ),
                if (!widget.hasMicPermission &&
                    widget.onRequestPermission != null)
                  TextButton(
                    onPressed: widget.onRequestPermission,
                    child: const Text('Grant'),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Recording status
            Row(
              children: [
                Icon(
                  widget.isRecording
                      ? widget.isPaused
                          ? Icons.pause_circle_filled
                          : Icons.record_voice_over
                      : Icons.voice_over_off,
                  color:
                      widget.isRecording
                          ? widget.isPaused
                              ? Colors.amber
                              : Colors.green
                          : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recording Status: ${widget.isRecording
                      ? widget.isPaused
                          ? "Paused"
                          : "Active"
                      : "Inactive"}',
                  style: TextStyle(
                    color:
                        widget.isRecording
                            ? widget.isPaused
                                ? Colors.amber
                                : Colors.green
                            : Colors.grey,
                  ),
                ),
              ],
            ),

            // API status
            if (_showAdvanced)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(
                      _getApiStatusIcon(),
                      color: _getApiStatusColor(),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'API Status: ${widget.apiStatus}',
                      style: TextStyle(color: _getApiStatusColor()),
                    ),
                  ],
                ),
              ),

            // Transcript stats
            if (_showAdvanced)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.text_snippet, size: 20),
                    const SizedBox(width: 8),
                    Text('Transcripts: ${widget.transcriptCount}'),
                    const SizedBox(width: 16),
                    if (widget.streamTimeMs > 0)
                      Text(
                        'Stream time: ${_formatDuration(widget.streamTimeMs)}',
                      ),
                  ],
                ),
              ),

            // Test result
            if (_testResult != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      _testResult!.contains("PASSED")
                          ? Colors.green.shade50
                          : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color:
                        _testResult!.contains("PASSED")
                            ? Colors.green.shade300
                            : Colors.amber.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testResult!.contains("PASSED")
                          ? Icons.check_circle
                          : Icons.warning,
                      color:
                          _testResult!.contains("PASSED")
                              ? Colors.green
                              : Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_testResult!)),
                  ],
                ),
              ),

            // Test buttons
            if (_showAdvanced)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.onTestMicrophone != null)
                      TextButton.icon(
                        icon: const Icon(Icons.mic, size: 16),
                        label: const Text('Test Mic'),
                        onPressed: _isTesting ? null : _runMicrophoneTest,
                      ),
                    if (widget.onTestApiConnection != null)
                      TextButton.icon(
                        icon: const Icon(Icons.cloud, size: 16),
                        label: const Text('Test API'),
                        onPressed: _isTesting ? null : _runApiTest,
                      ),
                  ],
                ),
              ),

            // Error message if any
            if (widget.hasError && widget.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                    if (widget.onRetry != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: widget.onRetry,
                          child: const Text('Retry'),
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

  String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _getPermissionStatusText() {
    if (_permissionStatus == null) return 'Checking...';

    switch (_permissionStatus!) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      default:
        return 'Unknown';
    }
  }

  IconData _getApiStatusIcon() {
    switch (widget.apiStatus.toLowerCase()) {
      case 'connected':
        return Icons.cloud_done;
      case 'connecting':
      case 'initializing':
        return Icons.cloud_sync;
      case 'disconnected':
      case 'error':
        return Icons.cloud_off;
      default:
        return Icons.cloud_queue;
    }
  }

  Color _getApiStatusColor() {
    switch (widget.apiStatus.toLowerCase()) {
      case 'connected':
        return Colors.green;
      case 'connecting':
      case 'initializing':
        return Colors.amber;
      case 'disconnected':
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
