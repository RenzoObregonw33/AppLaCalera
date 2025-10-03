// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:lacalera/screens/reset_password_screen.dart';
import 'package:lacalera/services/api_services.dart';
import 'package:lacalera/services/database_services.dart';
import 'package:lacalera/models/user_models.dart';
import 'package:lacalera/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;
  bool _ocultarPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🔥 VALIDADORES MEJORADOS
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su email';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Ingrese un email válido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su contraseña';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  // 🔥 LOGIN MEJORADO
  Future<void> _login() async {
    // Primero validar
    final emailError = _validateEmail(_emailController.text.trim());
    final passwordError = _validatePassword(_passwordController.text.trim());

    if (emailError != null || passwordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
      _passwordError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final response = await ApiService.login(email, password);

      if (response['success'] == true) {
        final user = User.fromJson(response['user']);

        // ✅ GUARDAR DATOS DE SESIÓN (esto te faltaba)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', response['token'] ?? '');
        await prefs.setInt('login_time', DateTime.now().millisecondsSinceEpoch);
        await prefs.setString('user_data', jsonEncode(response['user']));

        print('🔥 ===== INICIANDO SINCRONIZACIÓN DE BLACKLIST =====');
        print('👤 Usuario logueado exitosamente');
        print('🏢 Organizaciones del usuario: ${user.organizaciones.length}');
        for (var org in user.organizaciones) {
          print('   - ID: ${org.organiId}, Nombre: ${org.organiRazonSocial}');
        }
        print('🔥 ================================================');

        // 🔥 SINCRONIZAR BLACKLIST DESPUÉS DEL LOGIN
        await _syncBlacklistForUser(user);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(user: user)),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _passwordError = response['message'] ?? 'Error en el login';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _passwordError = 'Error de conexión. Verifique su internet';
      });
    }
  }

  // 🔥 NUEVO MÉTODO: Sincronizar blacklist para todas las organizaciones
  Future<void> _syncBlacklistForUser(User user) async {
    try {
      print("🔄 ===== FUNCIÓN _syncBlacklistForUser INICIADA =====");
      print("🏢 Sincronizando blacklist para ${user.organizaciones.length} organizaciones");
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      print('🔑 Token usado para blacklist: $token');
      
      for (var organizacion in user.organizaciones) {
        print('\n📡 ===== PROCESANDO ORGANIZACIÓN ${organizacion.organiId} =====');
        print('🏢 Nombre: ${organizacion.organiRazonSocial}');
        print('🔗 Llamando API para organiId: ${organizacion.organiId}');
        
        final blacklistResponse = await ApiService.fetchBlacklistFromApi(
          organizacion.organiId,
          token: token,
        );
        
        print('📥 ===== RESPUESTA DE API PARA ORG ${organizacion.organiId} =====');
        print('📊 Tipo de respuesta: ${blacklistResponse.runtimeType}');
        print('📊 Cantidad de registros: ${blacklistResponse.length}');
        print('📄 Primeros registros: ${blacklistResponse.take(3).toList()}');
        print('📥 =============================================');
        
        if (blacklistResponse.isNotEmpty) {
          print('💾 Guardando ${blacklistResponse.length} registros en base de datos...');
          await DatabaseService.syncBlacklistFromApi(blacklistResponse, organizacion.organiId);
          print("✅ Blacklist sincronizada para org: ${organizacion.organiRazonSocial}");
        } else {
          print("⚠️ Error sincronizando blacklist para org ${organizacion.organiId}: Sin datos recibidos");
        }
      }
      
      // 🔍 Mostrar todas las blacklists después de sincronizar
      print('\n🔍 ===== DEBUG: MOSTRANDO TODAS LAS BLACKLISTS =====');
      await DatabaseService.showAllBlacklists();
      
      // 🔧 Forzar sincronización manual como backup
      print('\n🔧 ===== EJECUTANDO SINCRONIZACIÓN MANUAL DE BACKUP =====');
      await DatabaseService.debugSyncBlacklist();
      
      // 🧪 Probar DNIs específicos de la organización 749
      if (user.organizaciones.any((org) => org.organiId == 749)) {
        print('\n🧪 ===== PROBANDO DNIs ESPECÍFICOS DE ORG 749 =====');
        await DatabaseService.testDniBlacklist('44781573', 749);
        await DatabaseService.testDniBlacklist('44781563', 749);
        await DatabaseService.testDniBlacklist('12345678', 749); // DNI que NO debe estar
        print('🧪 ===============================================');
      }
      
    } catch (e) {
      print("❌ Error en sincronización de blacklist: $e");
      // No bloqueamos el login si falla la sincronización
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logorh.png', // Cambia la ruta si tu logo tiene otro nombre o carpeta
                height: 100,
              ),
              const SizedBox(height: 16),
              const Text(
                'Hola de nuevo!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bienvenido de regreso,',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Text(
                'te extrañamos!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 50),

              // Campo de Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: _emailError != null
                        ? Colors.red
                        : const Color(0xFF1565C0),
                  ),
                  suffixIcon: _emailError != null
                      ? const Icon(Icons.error_outline, color: Colors.red)
                      : null,
                  errorText: _emailError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1565C0),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
                onChanged: (value) {
                  if (_emailError != null) {
                    setState(() {
                      _emailError = null;
                    });
                  }
                },
              ),

              const SizedBox(height: 20),

              // Campo de Password
              TextField(
                controller: _passwordController,
                obscureText: _ocultarPassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: _passwordError != null
                        ? Colors.red
                        : const Color(0xFF1565C0),
                  ),
                  suffixIcon: _passwordError != null
                      ? const Icon(Icons.error_outline, color: Colors.red)
                      : IconButton(
                          onPressed: () {
                            setState(() {
                              _ocultarPassword = !_ocultarPassword;
                            });
                          },
                          icon: Icon(
                            _ocultarPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                        ),
                  errorText: _passwordError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1565C0),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
                onChanged: (value) {
                  if (_passwordError != null) {
                    setState(() {
                      _passwordError = null;
                    });
                  }
                },
              ),

              // Enlace para recuperar contraseña
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ResetPasswordScreen(),
                            ),
                          );
                        },
                  child: const Text(
                    'Recuperar Contraseña',
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Botón de Login
              _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF1565C0),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
