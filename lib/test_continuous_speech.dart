// lib/test_continuous_speech.dart - For debugging Android continuous STT

import 'package:flutter/material.dart';
import 'package:hermes/core/services/speech_to_text/continuous_speech_channel.dart';
import 'package:hermes/core/services/speech_to_text/speech_result.dart';

class ContinuousSpeechTestPage extends StatefulWidget {
  const ContinuousSpeechTestPage({super.key});

  @override
  State<ContinuousSpeechTestPage> createState() =>
      _ContinuousSpeechTestPageState();
}

class _ContinuousSpeechTestPageState extends State<ContinuousSpeechTestPage> {
  final ContinuousSpeechChannel _speechChannel =
      ContinuousSpeechChannel.instance;

  final List<String> _logs = [];
  final List<SpeechResult> _results = [];
  bool _isListening = false;
  bool _isAvailable = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAndTest();
  }

  Future<void> _initializeAndTest() async {
    _addLog('🔍 Testing continuous speech availability...');

    try {
      // Check availability
      _isAvailable = await _speechChannel.isAvailable;
      _addLog('📱 Platform availability: $_isAvailable');

      if (_isAvailable) {
        // Try to initialize
        _isInitialized = await _speechChannel.initialize();
        _addLog('🚀 Initialization result: $_isInitialized');

        if (_isInitialized) {
          _addLog('✅ Continuous speech ready! You can now test speaking.');
        } else {
          _addLog('❌ Initialization failed - check platform implementation');
        }
      } else {
        _addLog('❌ Continuous speech not available on this platform');
      }
    } catch (e) {
      _addLog('💥 Error during setup: $e');
    }

    setState(() {});
  }

  Future<void> _startListening() async {
    if (!_isInitialized) {
      _addLog('❌ Not initialized - cannot start listening');
      return;
    }

    _addLog('🎤 Starting continuous listening...');

    try {
      await _speechChannel.startContinuousListening(
        locale: 'en-US',
        onResult: (SpeechResult result) {
          _addLog(
            '📝 Result: "${result.transcript}" (final: ${result.isFinal})',
          );
          setState(() {
            _results.add(result);
          });
        },
        onError: (String error) {
          _addLog('❌ Error: $error');
        },
      );

      setState(() {
        _isListening = true;
      });

      _addLog('✅ Listening started - speak now!');
    } catch (e) {
      _addLog('💥 Failed to start listening: $e');
    }
  }

  Future<void> _stopListening() async {
    _addLog('🛑 Stopping listening...');

    try {
      await _speechChannel.stopContinuousListening();
      setState(() {
        _isListening = false;
      });
      _addLog('✅ Listening stopped');
    } catch (e) {
      _addLog('💥 Error stopping: $e');
    }
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.add('[$timestamp] $message');
    });
    print('[ContinuousSpeechTest] $message');
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
      _results.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Continuous Speech Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status indicators
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                _StatusIndicator('Available', _isAvailable),
                const SizedBox(width: 16),
                _StatusIndicator('Initialized', _isInitialized),
                const SizedBox(width: 16),
                _StatusIndicator('Listening', _isListening),
              ],
            ),
          ),

          // Control buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isInitialized && !_isListening
                            ? _startListening
                            : null,
                    icon: const Icon(Icons.mic),
                    label: const Text('Start Listening'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isListening ? _stopListening : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Listening'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Recent results
          if (_results.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Results (${_results.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: _results.length,
                      reverse: true,
                      itemBuilder: (context, index) {
                        final result = _results[_results.length - 1 - index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            result.isFinal
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color:
                                result.isFinal ? Colors.green : Colors.orange,
                            size: 16,
                          ),
                          title: Text(
                            result.transcript,
                            style: TextStyle(
                              fontWeight:
                                  result.isFinal
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${result.timestamp.toString().substring(11, 19)} • ${result.isFinal ? 'Final' : 'Partial'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Debug logs
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bug_report, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Debug Logs (${_logs.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _logs.length,
                      reverse: true,
                      itemBuilder: (context, index) {
                        final log = _logs[_logs.length - 1 - index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton:
          _isListening
              ? FloatingActionButton(
                onPressed: _stopListening,
                backgroundColor: Colors.red,
                child: const Icon(Icons.stop, color: Colors.white),
              )
              : FloatingActionButton(
                onPressed: _isInitialized ? _startListening : null,
                child: const Icon(Icons.mic),
              ),
    );
  }

  @override
  void dispose() {
    if (_isListening) {
      _speechChannel.stopContinuousListening();
    }
    super.dispose();
  }
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final bool status;

  const _StatusIndicator(this.label, this.status);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: status ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
