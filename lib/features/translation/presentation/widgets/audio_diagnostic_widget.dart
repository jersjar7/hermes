// lib/features/translation/presentation/widgets/audio_diagnostic_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Widget that displays diagnostic information about audio recording
class AudioDiagnosticWidget extends StatefulWidget {
  /// Whether microphone permission is granted
  final bool hasMicPermission;

  /// Whether currently recording
  final bool isRecording;

  /// Whether there was an error
  final bool hasError;

  /// Error message, if any
  final String? errorMessage;

  /// Callback to request permissions
  final VoidCallback? onRequestPermission;

  /// Callback to retry recording
  final VoidCallback? onRetry;

  /// Creates a new [AudioDiagnosticWidget]
  const AudioDiagnosticWidget({
    super.key,
    required this.hasMicPermission,
    required this.isRecording,
    this.hasError = false,
    this.errorMessage,
    this.onRequestPermission,
    this.onRetry,
  });

  @override
  State<AudioDiagnosticWidget> createState() => _AudioDiagnosticWidgetState();
}

class _AudioDiagnosticWidgetState extends State<AudioDiagnosticWidget> {
  Timer? _refreshTimer;
  double _micLevel = 0.0;
  int _recordingSeconds = 0;
  PermissionStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();

    // Start a timer to simulate mic levels and update recording time
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {
          if (widget.isRecording) {
            // Simulate mic level with a sine wave
            _micLevel = (0.5 +
                    0.5 * (DateTime.now().millisecondsSinceEpoch % 2000) / 2000)
                .clamp(0.0, 1.0);

            if (DateTime.now().millisecondsSinceEpoch % 1000 < 100) {
              _recordingSeconds =
                  (_recordingSeconds + 1) % 3600; // Reset after an hour
            }
          } else {
            _micLevel = 0.0;
          }
        });
      }
    });
  }

  Future<void> _checkPermissionStatus() async {
    final status = await Permission.microphone.status;
    if (mounted) {
      setState(() {
        _permissionStatus = status;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
            const Text(
              'Audio Diagnostics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            const Divider(),

            // Permission status
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
                      ? Icons.record_voice_over
                      : Icons.voice_over_off,
                  color: widget.isRecording ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recording Status: ${widget.isRecording ? "Active" : "Inactive"}',
                  style: TextStyle(
                    color: widget.isRecording ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),

            // Recording time
            if (widget.isRecording)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Recording Time: ${_formatTime(_recordingSeconds)}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),

            // Mic level indicator
            if (widget.hasMicPermission)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Microphone Level:'),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _micLevel,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isRecording ? Colors.green : Colors.grey,
                        ),
                        minHeight: 10,
                      ),
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

  String _formatTime(int seconds) {
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
}
