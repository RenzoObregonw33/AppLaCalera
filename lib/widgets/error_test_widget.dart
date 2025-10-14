import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lacalera/services/database_services.dart';
import 'package:http/http.dart' as http;

/// Widget temporal para probar la captura de errores
/// 🗑️ ELIMINAR ESTE ARCHIVO DESPUÉS DE LAS PRUEBAS
class ErrorTestWidget extends StatelessWidget {
  const ErrorTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '🧪 Pruebas de Captura de Errores',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '⚠️ TEMPORAL - Eliminar después de pruebas',
              style: TextStyle(
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),

            // Botón 1: Error simple
            ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: const Text('Error Simple'),
              subtitle: const Text('Exception básica'),
              onTap: () => _generarErrorSimple(context),
            ),

            const Divider(),

            // Botón 2: Error de base de datos
            ListTile(
              leading: const Icon(Icons.storage, color: Colors.blue),
              title: const Text('Error de Base de Datos'),
              subtitle: const Text('Tabla inexistente'),
              onTap: () => _generarErrorBD(context),
            ),

            const Divider(),

            // Botón 3: Error de archivo
            ListTile(
              leading: const Icon(Icons.folder_off, color: Colors.purple),
              title: const Text('Error de Archivo'),
              subtitle: const Text('Archivo no encontrado'),
              onTap: () => _generarErrorArchivo(context),
            ),

            const Divider(),

            // Botón 4: Error de red
            ListTile(
              leading: const Icon(Icons.wifi_off, color: Colors.indigo),
              title: const Text('Error de Red'),
              subtitle: const Text('URL inválida'),
              onTap: () => _generarErrorRed(context),
            ),

            const Divider(),

            // Botón 5: Print de prueba
            ListTile(
              leading: const Icon(Icons.print, color: Colors.green),
              title: const Text('Print de Prueba'),
              subtitle: const Text('Mensaje en consola'),
              onTap: () => _generarPrint(context),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Error simple - siempre funciona
  void _generarErrorSimple(BuildContext context) {
    try {
      throw Exception(
        '🧪 Error de prueba generado a las ${DateTime.now().toLocal()}',
      );
    } catch (e) {
      print('Error simple capturado: $e');
      _mostrarMensaje(context, 'Error simple generado');
    }
  }

  // 2. Error de base de datos
  Future<void> _generarErrorBD(BuildContext context) async {
    try {
      final db = await DatabaseService.database;
      // Esto va a fallar porque la tabla no existe
      await db.rawQuery('SELECT * FROM tabla_que_no_existe_para_prueba');
    } catch (e) {
      print('Error de BD capturado: $e');
      _mostrarMensaje(context, 'Error de BD generado');
    }
  }

  // 3. Error de archivo
  Future<void> _generarErrorArchivo(BuildContext context) async {
    try {
      // Intentar leer un archivo que definitivamente no existe
      final file = File('/ruta/completamente/falsa/archivo_de_prueba.txt');
      await file.readAsString();
    } catch (e) {
      print('Error de archivo capturado: $e');
      _mostrarMensaje(context, 'Error de archivo generado');
    }
  }

  // 4. Error de red
  Future<void> _generarErrorRed(BuildContext context) async {
    try {
      // Intentar conectar a una URL que no existe
      final response = await http
          .get(Uri.parse('http://sitio-que-no-existe-para-pruebas.com/test'))
          .timeout(Duration(seconds: 5));
      print('Response: ${response.body}');
    } catch (e) {
      print('Error de red capturado: $e');
      _mostrarMensaje(context, 'Error de red generado');
    }
  }

  // 5. Print de prueba
  void _generarPrint(BuildContext context) {
    print('🧪 Print de prueba - ${DateTime.now()}');
    print('📱 Probando captura de prints normales');
    print('✅ Si ves esto en los logs, la captura funciona');
    _mostrarMensaje(context, 'Prints enviados a la consola');
  }

  // Helper para mostrar mensajes
  void _mostrarMensaje(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $mensaje - Revisa los logs'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
