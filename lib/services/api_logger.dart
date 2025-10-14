import '../screens/secret_screen.dart';

/// 📋 SERVICIO DE LOGGING PROFESIONAL PARA APIs
/// 
/// Genera logs con formato profesional:
/// 📅 15/10/2024 14:30:45 | ⚠️ [401] CLIENT_ERROR
/// 🌐 POST /web_services/login
/// 🎯 Función: login()
/// 📝 Estado: Unauthorized - Credenciales inválidas
/// 📤 Request: {email: juan@test.com, password: ***HIDDEN***}
/// 📥 Response: {success: false, message: Credenciales inválidas}
class ApiLogger {
  
  /// 🌐 LOG PRINCIPAL PARA LLAMADAS DE API
  /// 
  /// Registra todas las interacciones con APIs con formato profesional
  static Future<void> addApiLog({
    required String method, // GET, POST, PUT, DELETE
    required String endpoint, // /web_services/login
    required int statusCode, // 200, 403, 401, etc.
    required String function, // login, sendPersonToApi, etc.
    String? errorMessage, // Mensaje específico del error
    Map<String, dynamic>? requestData, // Datos enviados (sin passwords)
    Map<String, dynamic>? responseData, // Respuesta del servidor
    Duration? duration, // Tiempo que tomó la llamada
  }) async {
    try {
      final now = DateTime.now();
      final date = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
      final time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      
      // Determinar emoji, nivel y texto del estado según código HTTP
      final statusInfo = _getStatusInfo(statusCode);
      
      // Crear log con formato simplificado y limpio
      final logEntry = "📅 $date $time | ${statusInfo['emoji']} [$statusCode] ${statusInfo['level']}\n"
          "🌐 $method $endpoint\n"
          "🎯 Función: $function()\n"
          "📝 Estado: ${statusInfo['text']}${errorMessage != null ? ' - $errorMessage' : ''}\n"
          "📤 Request: ${_getEssentialData(requestData)}\n"
          "📥 Response: ${_getEssentialData(responseData)}\n"
          "─────────────────────────────────────────";

      // Enviar al sistema de logs del SecretScreen
      SecretScreen.addRawLog(logEntry);
      
    } catch (e) {
      print('⚠️ Error en ApiLogger.addApiLog: $e');
    }
  }

  /// 🚨 LOG ESPECÍFICO PARA ERRORES CAPTURADOS
  static Future<void> addErrorLog({
    required String error,
    required String function,
    String? context,
    StackTrace? stackTrace,
    String severity = 'ERROR', // ERROR, WARNING, CRITICAL
  }) async {
    try {
      final now = DateTime.now();
      final date = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
      final time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      
      // Emoji según severidad
      String emoji;
      switch (severity) {
        case 'WARNING':
          emoji = '⚠️';
          break;
        case 'CRITICAL':
          emoji = '🔥';
          break;
        default:
          emoji = '🚨';
      }
      
      final logEntry = "📅 $date $time | $emoji $severity\n"
          "💥 Error: $error\n"
          "🎯 Función: $function()\n"
          "${context != null ? '📍 Contexto: $context\n' : ''}"
          "─────────────────────────────────────────";

      SecretScreen.addRawLog(logEntry);
      
    } catch (e) {
      print('⚠️ Error en ApiLogger.addErrorLog: $e');
    }
  }

  /// 🔸 LOG PARA INFORMACIÓN GENERAL
  static Future<void> addInfoLog({
    required String message,
    required String function,
    String level = 'INFO', // INFO, DEBUG, TRACE
    Map<String, dynamic>? data,
  }) async {
    try {
      final now = DateTime.now();
      final date = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
      final time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      
      // Emoji según nivel
      String emoji;
      switch (level) {
        case 'DEBUG':
          emoji = '🔧';
          break;
        case 'TRACE':
          emoji = '🔍';
          break;
        default:
          emoji = '🔸';
      }
      
      final logEntry = "📅 $date $time | $emoji $level\n"
          "📝 Mensaje: $message\n"
          "🎯 Función: $function()\n"
          "─────────────────────────────────────────";

      SecretScreen.addRawLog(logEntry);
      
    } catch (e) {
      print('⚠️ Error en ApiLogger.addInfoLog: $e');
    }
  }

  // ════════════════════════════════════════
  // MÉTODOS PRIVADOS DE UTILIDAD
  // ════════════════════════════════════════

  /// 🔢 Determina información del código de estado HTTP
  static Map<String, String> _getStatusInfo(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return {
        'emoji': '✅',
        'level': 'SUCCESS',
        'text': _getStatusText(statusCode),
      };
    } else if (statusCode >= 300 && statusCode < 400) {
      return {
        'emoji': '🔄',
        'level': 'REDIRECT',
        'text': _getStatusText(statusCode),
      };
    } else if (statusCode >= 400 && statusCode < 500) {
      return {
        'emoji': '⚠️',
        'level': 'CLIENT_ERROR',
        'text': _getStatusText(statusCode),
      };
    } else if (statusCode >= 500) {
      return {
        'emoji': '💥',
        'level': 'SERVER_ERROR',
        'text': _getStatusText(statusCode),
      };
    } else {
      return {
        'emoji': '❓',
        'level': 'UNKNOWN',
        'text': 'Estado desconocido',
      };
    }
  }

  /// 📝 Obtiene texto descriptivo del código de estado HTTP
  static String _getStatusText(int statusCode) {
    switch (statusCode) {
      // 2xx Success
      case 200:
        return 'OK - Éxito';
      case 201:
        return 'Created - Recurso creado';
      case 204:
        return 'No Content - Sin contenido';
      
      // 3xx Redirection
      case 301:
        return 'Moved Permanently - Movido permanentemente';
      case 302:
        return 'Found - Encontrado';
      
      // 4xx Client Error
      case 400:
        return 'Bad Request - Solicitud incorrecta';
      case 401:
        return 'Unauthorized - Credenciales inválidas';
      case 403:
        return 'Forbidden - Prohibido';
      case 404:
        return 'Not Found - No encontrado';
      case 422:
        return 'Unprocessable Entity - Error de validación';
      case 429:
        return 'Too Many Requests - Demasiadas solicitudes';
      
      // 5xx Server Error
      case 500:
        return 'Internal Server Error - Error interno del servidor';
      case 502:
        return 'Bad Gateway - Gateway incorrecto';
      case 503:
        return 'Service Unavailable - Servicio no disponible';
      case 504:
        return 'Gateway Timeout - Timeout del gateway';
      
      // Network/Connection Error
      case 0:
        return 'Network Error - Error de conexión';
      
      default:
        return 'Código $statusCode';
    }
  }

  /// 📋 Extrae solo los datos esenciales (document e id)
  static String _getEssentialData(Map<String, dynamic>? data) {
    if (data == null) return 'N/A';
    
    final essential = <String, dynamic>{};
    
    // Solo extraer document e id
    if (data.containsKey('document')) {
      essential['document'] = data['document'];
    }
    if (data.containsKey('id')) {
      essential['id'] = data['id'];
    }
    
    // Si no hay datos esenciales, mostrar solo success/message
    if (essential.isEmpty) {
      if (data.containsKey('success')) {
        essential['success'] = data['success'];
      }
      if (data.containsKey('message')) {
        essential['message'] = data['message'];
      }
    }
    
    return essential.toString();
  }
}