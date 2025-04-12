// lib/features/translation/presentation/widgets/audio_level_indicator.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Widget that displays a real-time audio level indicator to show microphone activity
class AudioLevelIndicator extends StatefulWidget {
  /// Whether currently listening for audio
  final bool isListening;

  /// Height of the indicator
  final double height;

  /// Creates a new [AudioLevelIndicator]
  const AudioLevelIndicator({
    super.key,
    required this.isListening,
    this.height = 32.0,
  });

  @override
  State<AudioLevelIndicator> createState() => _AudioLevelIndicatorState();
}

class _AudioLevelIndicatorState extends State<AudioLevelIndicator> {
  double _level = 0.0;
  final _recorder = AudioRecorder();
  Timer? _levelTimer;
  bool _recorderInitialized = false;
  List<double> _visualizerLevels = List.filled(30, 0.05); // For visualization
  bool _hasPermission = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    setState(() {
      _hasPermission = status.isGranted;
      if (!_hasPermission) {
        _errorMessage = _getPermissionErrorMessage(status);
      } else {
        _startLevelMonitoring();
      }
    });
  }

  String _getPermissionErrorMessage(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.denied:
        return 'Microphone access denied. Please grant permission.';
      case PermissionStatus.permanentlyDenied:
        return 'Microphone permission permanently denied. Open app settings.';
      case PermissionStatus.restricted:
        return 'Microphone access is restricted on this device.';
      case PermissionStatus.limited:
        return 'Limited microphone access. Full access needed.';
      default:
        return 'Microphone permission required.';
    }
  }

  @override
  void didUpdateWidget(AudioLevelIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening && _hasPermission) {
        _startLevelMonitoring();
      } else if (!widget.isListening) {
        _stopLevelMonitoring();
      }
    }
  }

  void _startLevelMonitoring() async {
    // Already monitoring, skip
    if (_levelTimer != null) return;

    // Verify permission is granted
    if (!_hasPermission) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        setState(() {
          _hasPermission = false;
          _errorMessage = _getPermissionErrorMessage(status);
        });
        return;
      }
      _hasPermission = true;
      _errorMessage = null;
    }

    // Start recorder in a very quiet mode just to monitor levels
    try {
      // Make sure we're not already recording
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }

      // Get a temporary path for the output
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/audio_level_indicator.wav';

      // Start recording with a required path
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          bitRate: 16000,
          sampleRate: 8000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
        ),
        path: tempPath,
      );

      _recorderInitialized = true;
      _errorMessage = null;

      // Start periodic level monitoring
      _levelTimer = Timer.periodic(const Duration(milliseconds: 50), (
        timer,
      ) async {
        if (widget.isListening && mounted && _hasPermission) {
          try {
            final amplitude = await _recorder.getAmplitude();

            // The amplitude.current usually ranges from 0 to about 0.3 for speech
            // We'll normalize it to a 0-1 scale with sensible thresholds
            final normalizedLevel = (amplitude.current / 0.2).clamp(0.0, 1.0);

            if (mounted) {
              setState(() {
                _level = normalizedLevel;
                // Shift values in the visualizer array
                _visualizerLevels.removeAt(0);
                _visualizerLevels.add(
                  _level.clamp(0.05, 1.0),
                ); // Minimum height for aesthetics
              });
            }
          } catch (e) {
            // Show the error instead of silently handling it
            if (mounted) {
              setState(() {
                _errorMessage = "Error accessing microphone: $e";
              });
            }
          }
        }
      });
    } catch (e) {
      // Show the error instead of falling back to demo mode
      if (mounted) {
        setState(() {
          _recorderInitialized = false;
          _errorMessage = "Failed to initialize microphone: $e";
        });
      }
    }
  }

  void _stopLevelMonitoring() {
    _levelTimer?.cancel();
    _levelTimer = null;

    if (_recorderInitialized) {
      _recorder.stop().catchError((e) {
        // Show error if stopping fails
        if (mounted) {
          setState(() {
            _errorMessage = "Error stopping recorder: $e";
          });
        }
        return null; // explicitly return a String? to match method signature
      });
    }

    // Reset the visualization when stopped
    if (mounted) {
      setState(() {
        _visualizerLevels = List.filled(30, 0.05);
        _level = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _stopLevelMonitoring();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If we have an error, show it clearly
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return Container(
      height: widget.height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      child:
          widget.isListening && _hasPermission
              ? _buildActiveVisualizer()
              : _buildInactiveVisualizer(),
    );
  }

  Widget _buildErrorView() {
    return Container(
      height:
          widget.height + 20, // Make it a bit taller to fit the error message
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_off, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? "Microphone error",
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
              _checkPermission();
            },
            tooltip: 'Retry',
          ),
        ],
      ),
    );
  }

  Widget _buildActiveVisualizer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_visualizerLevels.length, (index) {
        return _buildBar(_visualizerLevels[index]);
      }),
    );
  }

  Widget _buildInactiveVisualizer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_visualizerLevels.length, (index) {
        // When inactive, show a flat line with tiny bars
        return _buildBar(0.05);
      }),
    );
  }

  Widget _buildBar(double level) {
    final bool isActive = widget.isListening && _hasPermission && level > 0.1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      width:
          (MediaQuery.of(context).size.width - 40) / _visualizerLevels.length -
          2,
      height: widget.height * level,
      decoration: BoxDecoration(
        color:
            isActive
                ? Color.lerp(
                  Colors.green.shade300,
                  Colors.green.shade700,
                  level,
                )
                : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
