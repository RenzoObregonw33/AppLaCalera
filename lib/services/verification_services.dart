import 'package:lacalera/services/database_services.dart';

class VerificationService {
  // Verificar si un DNI está en blacklist
  static Future<Map<String, dynamic>> verifyDni(String dni) async {
    try {
      final result = await DatabaseService.checkDniInBlacklist(dni);
      
      if (result['isBlacklisted'] == true) {
        final blacklistData = result['data'];
        return {
          'isValid': false,
          'message': '⚠️ DNI encontrado en lista negra',
          'reason': blacklistData?['reason'] ?? 'Razón no especificada',
          'blacklistData': blacklistData,
        };
      }
      
      return {
        'isValid': true,
        'message': '✅ DNI válido',
      };
    } catch (e) {
      return {
        'isValid': false,
        'message': '❌ Error verificando DNI: $e',
      };
    }
  }

  // Verificar formato de DNI (8 dígitos)
  static bool isValidDniFormat(String dni) {
    final dniRegex = RegExp(r'^\d{8}$');
    return dniRegex.hasMatch(dni);
  }
}