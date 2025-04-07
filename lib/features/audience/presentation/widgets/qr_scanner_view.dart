// lib/features/audience/presentation/widgets/qr_scanner_view.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/presentation/widgets/language_dropdown.dart';

/// Widget for scanning QR codes to join a session
class QrScannerView extends StatefulWidget {
  /// Callback when a QR code is detected
  final ValueChanged<String> onCodeDetected;

  /// Currently selected language
  final LanguageSelection selectedLanguage;

  /// Callback when language is changed
  final ValueChanged<LanguageSelection> onLanguageChanged;

  /// Error message to display (if any)
  final String? errorMessage;

  /// Creates a new [QrScannerView]
  const QrScannerView({
    super.key,
    required this.onCodeDetected,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    this.errorMessage,
  });

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  MobileScannerController? _controller;
  bool _hasPermission = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      final controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );

      // Wait for camera to initialize
      await controller.start();

      setState(() {
        _controller = controller;
        _hasPermission = true;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _hasPermission = false;
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Error message (if any)
        if (widget.errorMessage != null)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.errorMessage!,
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),

        // QR scanner or placeholder
        Expanded(child: _buildScannerView()),

        // Language selection at bottom
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: LanguageDropdown(
            selectedLanguage: widget.selectedLanguage,
            onChanged: widget.onLanguageChanged,
            label: 'Select your preferred language:',
          ),
        ),
      ],
    );
  }

  Widget _buildScannerView() {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Camera permission required',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enable camera access to scan QR codes',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeScanner,
              child: const Text('Request Permission'),
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera view
        MobileScanner(
          controller: _controller!,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              final rawValue = barcode.rawValue;
              if (rawValue != null && rawValue.isNotEmpty) {
                widget.onCodeDetected(rawValue);
                return;
              }
            }
          },
        ),

        // Overlay with scan area indication
        CustomPaint(painter: ScanAreaPainter(), child: const SizedBox.expand()),

        // Instructions at the bottom
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Point camera at the session QR code',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the scan area overlay
class ScanAreaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Calculate scan area size (70% of the smallest dimension)
    final scanAreaSize = width < height ? width * 0.7 : height * 0.7;

    // Calculate top-left corner of scan area
    final left = (width - scanAreaSize) / 2;
    final top = (height - scanAreaSize) / 2;

    // Create the scan area rect
    final scanArea = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    // Create path for the transparent "hole"
    final transparentHole = Path()..addRect(scanArea);

    // Create path for the whole screen
    final fullScreen = Path()..addRect(Rect.fromLTWH(0, 0, width, height));

    // Create path for the overlay (screen minus hole)
    final overlay = Path.combine(
      PathOperation.difference,
      fullScreen,
      transparentHole,
    );

    // Paint the overlay
    final paint =
        Paint()
          ..color = Colors.black.withOpacity(0.5)
          ..style = PaintingStyle.fill;

    canvas.drawPath(overlay, paint);

    // Draw scanning area corners
    final cornerPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;

    final cornerLength = scanAreaSize * 0.1;

    // Top-left corner
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top),
      Offset(left + scanAreaSize, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top),
      Offset(left + scanAreaSize, top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(left, top + scanAreaSize - cornerLength),
      Offset(left, top + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + scanAreaSize),
      Offset(left + cornerLength, top + scanAreaSize),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
