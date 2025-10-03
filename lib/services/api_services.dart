import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  /// Enviar datos de personas a la API
  static Future<Map<String, dynamic>> sendPersonToApi({
    required String document,
    required int id,
    required String movil,
    String? photoFrontBase64,
    String? photoReverseBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token') ?? '';
    
    print('🔍 ===== DEBUG ENVÍO API =====');
    print('📋 Document: $document');
    print('🏢 Organi ID: $id');
    print('📱 Móvil: $movil');
    print('🔑 Token: ${authToken.isNotEmpty ? "Presente (${authToken.length} chars)" : "VACÍO"}');
    
    final url = Uri.parse('$baseUrl/web_services/verify-document');
    final body = {
      'document': document,
      'id': id,
      'movil': movil,
      'photo_front': photoFrontBase64,
      'photo_reverse': photoReverseBase64,
    };
    print('🔗 URL: $url');
    print('📦 Body: ${jsonEncode(body)}');
    print('� ============================');
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
      print('📬 Status code: ${response.statusCode}');
      print('📩 Respuesta body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? '',
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error al enviar persona a API: $e');
      
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
    print('🔗 URL Blacklist: $url');
    print('🔑 Token recibido en API: $token');
    print(
      '📝 Header Authorization: ${token != null && token.isNotEmpty ? token : 'NO TOKEN'}',
    );
    print('📦 Body enviado: ${jsonEncode({'id': organiId})}');
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

      print('📬 Status code: ${response.statusCode}');
      print('📩 Respuesta body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🗃️ Decoded data: $data');
        
        // Verificar si la respuesta es directamente un array
        if (data is List) {
          print('✅ Respuesta directa como array (${data.length} registros)');
          return List<Map<String, dynamic>>.from(data);
        }
        // O si viene en formato con success y blacklisted
        else if (data['success'] == true && data['blacklisted'] is List) {
          print('✅ Blacklist en formato success/blacklisted (${data['blacklisted'].length} registros)');
          return List<Map<String, dynamic>>.from(data['blacklisted']);
        } else {
          print('⚠️ Respuesta sin blacklist válida: $data');
        }
      } else {
        print('❌ Status code no es 200: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('❌ Error al obtener blacklist de API: $e');
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

      print("📩 Respuesta cruda: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Guardamos datos de forma segura
        final prefs = await SharedPreferences.getInstance();

        final token = data['token'];
        if (token != null) {
          await prefs.setString('auth_token', token);
          print('🔑 Token guardado en prefs: $token');
        } else {
          print('⚠️ No se recibió token en el login');
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
      return {'success': false, 'message': 'Ups, revisa tu conexión a internet'};
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

      print("📡 Respuesta Blacklist API: ${response.statusCode}");

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

      // Imprime el código de estado y el cuerpo de la respuesta para depuración
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

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
      // Manejo de errores de conexión o tiempo de espera
      return {'success': false, 'message': 'Ups, revisa tu conexión a internet'};
    }
  }
}
