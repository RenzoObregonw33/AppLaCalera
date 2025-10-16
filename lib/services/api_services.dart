import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_logger.dart';

class ApiService {
  /// 🎬 MÉTODO DE DEMOSTRACIÓN - Genera el ejemplo exacto de log solicitado
  static Future<void> demoApiLogger() async {
    // Ejemplo 1: Error 401 como el solicitado
    await ApiLogger.addApiLog(
      method: 'POST',
      endpoint: '/web_services/login',
      statusCode: 401,
      function: 'login',
      errorMessage: 'Credenciales inválidas',
      requestData: {
        'email': 'juan@test.com',
        'password': 'secretpassword123', // Se va a ocultar automáticamente
      },
      responseData: {'success': false, 'message': 'Credenciales inválidas'},
    );

    // Ejemplo 2: Éxito 200
    await ApiLogger.addApiLog(
      method: 'POST',
      endpoint: '/web_services/verify-document',
      statusCode: 200,
      function: 'sendPersonToApi',
      requestData: {'document': '12345678', 'id': 1, 'movil': '3001234567'},
      responseData: {
        'success': true,
        'message': 'Documento verificado correctamente',
      },
    );
  }

  static Future<Map<String, dynamic>> sendPersonToApi({
    required String document,
    required int id,
    required String movil,
    String? photoFrontBase64,
    String? photoReverseBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token') ?? '';

    final url = Uri.parse('$baseUrl/web_services/verify-document');
    final body = {
      'document': document,
      'id': id,
      'movil': movil,
      'photo_front': photoFrontBase64,
      'photo_reverse': photoReverseBase64,
    };

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (authToken.isNotEmpty) 'Authorization': authToken,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 🔸 Log éxito de API con formato profesional
        await ApiLogger.addApiLog(
          method: 'POST',
          endpoint: '/web_services/verify-document',
          statusCode: 200,
          function: 'sendPersonToApi',
          requestData: body,
          responseData: data,
        );

        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? '',
        };
      } else {
        // 🚨 Log error de API con formato profesional
        try {
          final data = jsonDecode(response.body);

          // Ejemplo del formato solicitado para errores
          await ApiLogger.addApiLog(
            method: 'POST',
            endpoint: '/web_services/verify-document',
            statusCode: response.statusCode,
            function: 'sendPersonToApi',
            requestData: body,
            responseData: data,
            errorMessage: response.statusCode == 401
                ? 'Credenciales inválidas'
                : null,
          );

          return {
            'success': false,
            'message':
                data['message'] ?? 'Error del servidor: ${response.statusCode}',
          };
        } catch (e) {
          // Si no se puede parsear la respuesta, usar mensaje por defecto
          return {
            'success': false,
            'message': 'Error del servidor: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      // 🚨 Log excepción de red con formato profesional
      await ApiLogger.addErrorLog(
        error: 'NETWORK ERROR: ${e.toString()}',
        function: 'sendPersonToApi',
        context: 'verify-document API call',
        severity: 'HANDLED_ERROR',
      );

      // Manejo específico de errores comunes en dispositivos reales
      String errorMessage = 'Error de conexión';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Conexión lenta, inténtalo de nuevo';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Sin conexión a internet';
      } else if (e.toString().contains('HandshakeException')) {
        errorMessage = 'Error de certificado SSL';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Error en formato de respuesta del servidor';
      }

      return {'success': false, 'message': errorMessage};
    }
  }

  /// Obtiene la blacklist desde la API y la retorna como lista de mapas.
  static Future<List<Map<String, dynamic>>> fetchBlacklistFromApi(
    int organiId, {
    String? token,
  }) async {
    final url = Uri.parse('$baseUrl/web_services/black-list');
    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null && token.isNotEmpty) 'Authorization': token,
            },
            body: jsonEncode({'id': organiId}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Verificar si la respuesta es directamente un array
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        // O si viene en formato con success y blacklisted
        else if (data['success'] == true && data['blacklisted'] is List) {
          return List<Map<String, dynamic>>.from(data['blacklisted']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static const String baseUrl = 'https://rhnube.com.pe/api';

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/web_services/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Guardamos datos de forma segura
        final prefs = await SharedPreferences.getInstance();

        final token = data['token'];
        if (token != null) {
          await prefs.setString('auth_token', token);
        } else {
          return {
            'success': false,
            'message': 'No se recibió token en el login',
          };
        }
        // Guardar fecha/hora de login (en milisegundos)
        await prefs.setInt('login_time', DateTime.now().millisecondsSinceEpoch);

        final user = data['user'];
        if (user != null) {
          await prefs.setString(
            'user_data',
            jsonEncode(user),
          ); // 👈 Guardamos todo el objeto
          if (user['foto_url'] != null) {
            await prefs.setString('user_photo_url', user['foto_url']);
          }
        }

        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'Sin mensaje',
          'user': user ?? {},
          'token': token ?? '',
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Contraseña incorrecta'};
      } else if (response.statusCode == 422) {
        return {'success': false, 'message': 'Credenciales incorrectas'};
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      // 🚨 Log excepción de red con formato profesional
      await ApiLogger.addErrorLog(
        error: 'NETWORK ERROR: ${e.toString()}',
        function: 'fetchBlacklistFromApi',
        context: 'black-list API call',
        severity: 'HANDLED_ERROR',
      );

      return {
        'success': false,
        'message': 'Ups, revisa tu conexión a internet',
      };
    }
  }

  // 🔥 NUEVO MÉTODO: Obtener blacklist desde la API
  static Future<Map<String, dynamic>> getBlacklist(int organiId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token') ?? '';
      final response = await http
          .post(
            Uri.parse('$baseUrl/web_services/black-list'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (authToken.isNotEmpty) 'Authorization': authToken,
            },
            body: jsonEncode({'id': organiId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false,
          'blacklisted': data['blacklisted'] ?? [],
          'message': data['message'] ?? 'Blacklist obtenida correctamente',
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
          'blacklisted': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
        'blacklisted': [],
      };
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email) async {
    final url = Uri.parse('$baseUrl/web_services/password-reset');

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));

      // Si el correo fue enviado correctamente (200 OK)
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Correo enviado correctamente'};

        // Si hubo un error al enviar el correo (400 Bad Request)
      } else if (response.statusCode == 400) {
        return {'success': false, 'message': 'Correo no enviado'};

        // Si hay errores de validación (422 Unprocessable Entity)
      } else if (response.statusCode == 422) {
        final body = jsonDecode(response.body);
        final errors = body['errors'] ?? {};
        final emailError = errors['email']?[0];

        return {
          'success': false,
          'emailError': emailError,
          'message': body['message'] ?? 'Error de validación',
        };

        // Para otros códigos de estado
      } else {
        return {'success': false, 'message': 'Error: ${response.statusCode}'};
      }
    } catch (e) {
      // 🚨 Log excepción de red con formato profesional
      await ApiLogger.addErrorLog(
        error: 'NETWORK ERROR: ${e.toString()}',
        function: 'getBlacklist',
        context: 'black-list API call',
        severity: 'HANDLED_ERROR',
      );

      // Manejo de errores de conexión o tiempo de espera
      return {
        'success': false,
        'message': 'Ups, revisa tu conexión a internet',
      };
    }
  }
}
