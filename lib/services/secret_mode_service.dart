import 'package:flutter/foundation.dart';
import '../screens/secret_screen.dart';

class SecretModeService extends ChangeNotifier {
  static final SecretModeService _instance = SecretModeService._internal();
  factory SecretModeService() => _instance;
  SecretModeService._internal();

  bool _errorModeEnabled = false;

  bool get isErrorModeEnabled => _errorModeEnabled;

  void enableErrorMode() {
    if (!_errorModeEnabled) {
      _errorModeEnabled = true;

      // 🚀 INICIAR CAPTURA AUTOMÁTICAMENTE
      SecretScreen.startLogCapture();

      notifyListeners();
    }
  }

  void disableErrorMode() {
    if (_errorModeEnabled) {
      _errorModeEnabled = false;

      // 🛑 DETENER CAPTURA AL DESACTIVAR
      SecretScreen.stopLogCapture();

      notifyListeners();
    }
  }

  // 🚨 MÉTODO ESTÁTICO PARA DESACTIVAR MODO SECRETO AL CERRAR SESIÓN
  // (SIN borrar logs - para eso está el botón "Limpiar")
  static void clearSecretMode() {
    final instance = SecretModeService();
    if (instance._errorModeEnabled) {
      instance._errorModeEnabled = false;

      // 🛑 SOLO DETENER CAPTURA (mantener logs para revisión posterior)
      SecretScreen.stopLogCapture();

      instance.notifyListeners();
    }
  }
}
