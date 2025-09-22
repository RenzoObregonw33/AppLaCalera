import 'package:flutter/material.dart';
import 'package:lacalera/services/api_services.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); 
  String? _error;
  bool _enviado = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Enfocar automáticamente al iniciar
    Future.delayed(Duration.zero, () {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {                        
    _emailController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _enviarSolicitud() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _error = 'Ingresa tu correo electrónico');
      return;
    }

    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      setState(() => _error = 'Correo electrónico inválido');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ApiService.resetPassword(email);
      
      if (result['success'] == true) {
        setState(() {
          _enviado = true;
          _isLoading = false;
        });
        _mostrarMensaje(result['message']);
      } else {
        setState(() {
          _isLoading = false;
          _error = result['emailError'] ?? result['message'];
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _mostrarMensaje('Error: $e', error: true);
    }
  }

  void _mostrarMensaje(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(color: Colors.white)),
        backgroundColor: error ? Colors.red : const Color(0xFF1565C0),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(  
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Recuperar contraseña', 
          style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),                        
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Introduce tu dirección de correo electrónico:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                labelStyle: const TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.email_outlined, 
                  color: _error != null ? Colors.red : const Color(0xFF1565C0)),
                errorText: _error,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
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
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
            const SizedBox(height: 20),
            // Botón para enviar la solicitud
            SizedBox(
              width: double.infinity,
              height: 50,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _enviado 
                            ? Colors.grey 
                            : const Color(0xFF1565C0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _enviado ? null : _enviarSolicitud,
                      child: const Text(
                        'Enviar notificación',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}