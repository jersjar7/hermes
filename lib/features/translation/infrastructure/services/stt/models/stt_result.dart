// lib/features/translation/infrastructure/services/stt/models/stt_result.dart

/// Model class for speech recognition results
class SpeechRecognitionResult {
  /// Recognized text
  final String transcript;

  /// Confidence score (0.0 to 1.0)
  final double confidence;

  /// Whether this is a final result
  final bool isFinal;

  /// Stability score for streaming results (0.0 to 1.0)
  final double stability;

  /// Creates a new [SpeechRecognitionResult]
  SpeechRecognitionResult({
    required this.transcript,
    required this.confidence,
    required this.isFinal,
    this.stability = 0.0,
  });

  /// Create result from JSON
  factory SpeechRecognitionResult.fromJson(Map<String, dynamic> json) {
    print("[STT_DEBUG] Creating SpeechRecognitionResult from JSON: $json");

    // Extract the transcript from either streaming or batch response format
    String transcript = '';
    double confidence = 0.0;
    bool isFinal = false;
    double stability = 0.0;

    if (json.containsKey('results')) {
      print("[STT_DEBUG] Batch response format detected");
      // Batch response format
      final alternatives = json['results'][0]['alternatives'];
      if (alternatives.isNotEmpty) {
        transcript = alternatives[0]['transcript'] ?? '';
        confidence = alternatives[0]['confidence']?.toDouble() ?? 0.0;
      }
      isFinal = true;
    } else if (json.containsKey('result')) {
      print("[STT_DEBUG] Streaming response format detected");
      // Streaming response format
      final result = json['result'];

      if (result.containsKey('alternatives') &&
          result['alternatives'].isNotEmpty) {
        transcript = result['alternatives'][0]['transcript'] ?? '';
        confidence = result['alternatives'][0]['confidence']?.toDouble() ?? 0.0;
      }

      isFinal = result['isFinal'] ?? false;
      stability = result['stability']?.toDouble() ?? 0.0;
    }

    print(
      "[STT_DEBUG] Created result: transcript='$transcript', isFinal=$isFinal",
    );
    return SpeechRecognitionResult(
      transcript: transcript,
      confidence: confidence,
      isFinal: isFinal,
      stability: stability,
    );
  }
}
