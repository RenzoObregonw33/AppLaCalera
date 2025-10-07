import 'package:flutter/foundation.dart';

class SecretModeService extends ChangeNotifier {
  static final SecretModeService _instance = SecretModeService._internal();
  factory SecretModeService() => _instance;
  SecretModeService._internal();

  bool _errorModeEnabled = false;

  bool get isErrorModeEnabled => _errorModeEnabled;

  void enableErrorMode() {
    if (!_errorModeEnabled) {
      _errorModeEnabled = true;
      notifyListeners();
    }
  }

  void disableErrorMode() {
    if (_errorModeEnabled) {
      _errorModeEnabled = false;
      notifyListeners();
    }
  }
}