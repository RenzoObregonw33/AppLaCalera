import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
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
      return {'success': false, 'message': 'Error de conexión: $e'};
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
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }
}
