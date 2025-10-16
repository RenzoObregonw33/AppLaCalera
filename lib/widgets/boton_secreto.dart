import 'package:flutter/material.dart';
import '../services/secret_mode_service.dart';

class BotonSecreto extends StatefulWidget {
  final Widget child;
  final VoidCallback onSecretActivated;
  final int tapCountRequired;

  const BotonSecreto({
    super.key,
    required this.child,
    required this.onSecretActivated,
    this.tapCountRequired = 7,
  });

  @override
  State<BotonSecreto> createState() => _BotonSecretoState();
}

class _BotonSecretoState extends State<BotonSecreto> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _handleTap() {
    final now = DateTime.now();

    // Reset counter if more than 2 seconds have passed
    if (_lastTap != null && now.difference(_lastTap!).inSeconds > 2) {
      _tapCount = 0;
    }

    _lastTap = now;
    _tapCount++;

    // Activate secret when required taps reached
    if (_tapCount >= widget.tapCountRequired) {
      _tapCount = 0; // Reset counter

      // Activar modo errores globalmente
      SecretModeService().enableErrorMode();

      _showActivationEffect();
      widget.onSecretActivated();
    }
  }

  void _showActivationEffect() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.bug_report, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Modo Debug activado',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.black,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
