// lib/features/translation/presentation/widgets/enhanced_audio_level_indicator.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Enhanced widget that displays a real-time audio level indicator with debugging info
class EnhancedAudioLevelIndicator extends StatefulWidget {
  /// Whether currently listening for audio
  final bool isListening;

  /// Height of the indicator
  final double height;

  /// Whether to show detailed debugging information
  final bool showDebugInfo;

  /// Creates a new [EnhancedAudioLevelIndicator]
  const EnhancedAudioLevelIndicator({
    super.key,
    required this.isListening,
    this.height = 32.0,
    this.showDebugInfo = false,
  });

  @override
  State<EnhancedAudioLevelIndicator> createState() =>
      _EnhancedAudioLevelIndicatorState();
}

class _EnhancedAudioLevelIndicatorState
    extends State<EnhancedAudioLevelIndicator> {
  double _level = 0.0;
  final _recorder = AudioRecorder();
  Timer? _levelTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  // Make this a growable list to avoid "Cannot remove from a fixed-length list" error
  List<double> _visualizerLevels = List.filled(30, 0.05, growable: true);
  bool _hasPermission = false;
  String? _errorMessage;
  DateTime? _lastDetectedSoundTime;
  bool _isDisposed = false; // Track if widget is disposed

  // Stats tracking
  int _totalSamples = 0;
  int _activeSamples = 0;
  double _maxLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    try {
      // Just check if the recorder works and supports the required encoder
      final isEncoderSupported = await _recorder.isEncoderSupported(
        AudioEncoder.pcm16bits,
      );
      setState(() {
        _hasPermission = isEncoderSupported;
        if (!isEncoderSupported) {
          _errorMessage = 'Device does not support required audio encoding';
        }
      });

      // If we're supposed to be listening, start the audio monitor
      if (widget.isListening && _hasPermission) {
        _startAudioMonitoring();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing recorder: $e';
      });
    }
  }

  @override
  void didUpdateWidget(EnhancedAudioLevelIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening && _hasPermission) {
        _startAudioMonitoring();
      } else if (!widget.isListening) {
        _stopAudioMonitoring();
      }
    }
  }

  void _startAudioMonitoring() async {
    if (_amplitudeSubscription != null) return; // Already monitoring

    try {
      // Get a temporary path for the output
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/audio_level_debug.wav';

      // Start recording
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          bitRate: 16000,
          sampleRate: 8000,
          numChannels: 1,
          autoGain: true,
        ),
        path: tempPath,
      );

      // Setup amplitude monitoring
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amplitude) {
            if (_isDisposed) return;

            final currentLevel = (amplitude.current / 0.2).clamp(0.0, 1.0);

            setState(() {
              _level = currentLevel;
              _totalSamples++;

              // Track stats
              if (currentLevel > 0.1) {
                _activeSamples++;
                _lastDetectedSoundTime = DateTime.now();
                debugPrint(
                  "[DEBUG_AUDIO] Sound detected: ${currentLevel.toStringAsFixed(2)}",
                );
              }

              if (currentLevel > _maxLevel) {
                _maxLevel = currentLevel;
              }

              // Update visualizer levels
              final newLevels = List<double>.from(_visualizerLevels.sublist(1));
              newLevels.add(_level.clamp(0.05, 1.0));
              _visualizerLevels = newLevels;
            });
          });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error monitoring audio: $e';
      });
    }
  }

  void _stopAudioMonitoring() async {
    // Cancel subscription first to stop receiving updates
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    // Then stop recording
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      debugPrint('Error stopping recorder: $e');
    }

    if (!_isDisposed) {
      setState(() {
        _visualizerLevels = List.filled(30, 0.05, growable: true);
        _level = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopAudioMonitoring();
    _levelTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: widget.height,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          child: Row(
            children: List.generate(_visualizerLevels.length, (index) {
              return _buildBar(_visualizerLevels[index]);
            }),
          ),
        ),

        if (widget.showDebugInfo) _buildDebugInfo(),
      ],
    );
  }

  Widget _buildErrorView() {
    return Container(
      height: widget.height + 20,
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
        ],
      ),
    );
  }

  Widget _buildBar(double level) {
    final bool isActive = widget.isListening && level > 0.1;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        margin: const EdgeInsets.symmetric(horizontal: 1),
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
      ),
    );
  }

  Widget _buildDebugInfo() {
    final soundStatus = _level > 0.1 ? 'ACTIVE' : 'Quiet';
    final timeSinceLastSound =
        _lastDetectedSoundTime != null
            ? DateTime.now().difference(_lastDetectedSoundTime!).inMilliseconds
            : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level: ${(_level * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      _level > 0.1 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                'Max: ${(_maxLevel * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status: $soundStatus',
                style: TextStyle(
                  fontSize: 10,
                  color: _level > 0.1 ? Colors.green : Colors.grey,
                ),
              ),
              if (timeSinceLastSound != null)
                Text(
                  'Last sound: ${timeSinceLastSound}ms ago',
                  style: const TextStyle(fontSize: 10),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active: $_activeSamples / $_totalSamples',
                style: const TextStyle(fontSize: 10),
              ),
              Text(
                'Activity: ${_totalSamples > 0 ? (_activeSamples * 100 / _totalSamples).toStringAsFixed(1) : 0}%',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
