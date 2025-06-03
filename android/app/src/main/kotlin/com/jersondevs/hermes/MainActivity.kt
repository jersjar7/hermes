package com.jersondevs.hermes

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine


class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 🎯 Register the continuous speech plugin
        flutterEngine.plugins.add(ContinuousSpeechPlugin())
    }
}
