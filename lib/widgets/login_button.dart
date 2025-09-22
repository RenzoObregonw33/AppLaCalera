// login_button.dart
import 'package:lacalera/services/api_services.dart';
import 'package:lacalera/models/user_models.dart';
import 'package:flutter/material.dart';


class LoginButton extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final Function({String? emailError, String? passwordError}) onError;
  final Function(User user) onSuccess;

  const LoginButton({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onError,
    required this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final email = emailController.text.trim();
        final password = passwordController.text.trim();

        // Validaciones básicas
        if (email.isEmpty) {
          onError(emailError: 'Por favor ingrese su email');
          return;
        }

        if (password.isEmpty) {
          onError(passwordError: 'Por favor ingrese su contraseña');
          return;
        }

        try {
          final response = await ApiService.login(email, password);
          
          if (response['success'] == true) {
            final user = User.fromJson(response['user']);
            onSuccess(user);
          } else {
            onError(emailError: response['message'] ?? 'Error en el login');
          }
        } catch (e) {
          onError(emailError: 'Error de conexión: $e');
        }
      },
      child: const Text('Iniciar Sesión'),
    );
  }
}