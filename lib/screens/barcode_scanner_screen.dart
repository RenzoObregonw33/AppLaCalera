// lib/screens/barcode_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(String) onBarcodeScanned;

  const BarcodeScannerScreen({super.key, required this.onBarcodeScanned});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _isTorchOn = false;
  bool _isFrontCamera = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear código de barras'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            color: Colors.white,
            icon: _isTorchOn
                ? const Icon(Icons.flash_on, color: Colors.yellow)
                : const Icon(Icons.flash_off, color: Colors.grey),
            iconSize: 32.0,
            onPressed: () {
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
              cameraController.toggleTorch();
            },
          ),
          IconButton(
            color: Colors.white,
            icon: _isFrontCamera
                ? const Icon(Icons.camera_front)
                : const Icon(Icons.camera_rear),
            iconSize: 32.0,
            onPressed: () {
              setState(() {
                _isFrontCamera = !_isFrontCamera;
              });
              cameraController.switchCamera();
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          if (!_isScanning) return;

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? code = barcodes.first.rawValue;
            if (code != null && code.isNotEmpty) {
              setState(() {
                _isScanning = false;
              });
              
              widget.onBarcodeScanned(code);
              Navigator.pop(context);
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}