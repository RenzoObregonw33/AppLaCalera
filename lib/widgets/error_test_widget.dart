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
      elevation: 4,
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.science, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🧪 PANEL DE PRUEBAS - CAPTURA DE ERRORES',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Instrucciones
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 CÓMO USAR:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '1. Presiona "Iniciar Log Capture" arriba\n'
                    '2. Presiona cualquier botón de prueba abajo\n'
                    '3. Observa los errores aparecer en tiempo real',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),

            // Botón 1: Print simple
            _buildTestButton(
              context,
              icon: Icons.print,
              iconColor: Colors.green,
              title: '📝 Print Simple',
              subtitle: 'debugPrint() normal',
              onTap: () => _generarPrint(context),
            ),

            const Divider(),

            // Botón 2: Error simple
            _buildTestButton(
              context,
              icon: Icons.error,
              iconColor: Colors.red,
              title: '💥 Error Simple',
              subtitle: 'Exception básica',
              onTap: () => _generarErrorSimple(context),
            ),

            const Divider(),

            // Botón 3: Error de base de datos
            _buildTestButton(
              context,
              icon: Icons.storage,
              iconColor: Colors.blue,
              title: '🗄️ Error de Base de Datos',
              subtitle: 'Query a tabla inexistente',
              onTap: () => _generarErrorBD(context),
            ),

            const Divider(),

            // Botón 4: Error de red
            _buildTestButton(
              context,
              icon: Icons.wifi_off,
              iconColor: Colors.indigo,
              title: '🌐 Error de Red',
              subtitle: 'URL inválida con timeout',
              onTap: () => _generarErrorRed(context),
            ),

            const Divider(),

            // Botón 5: Múltiples eventos
            _buildTestButton(
              context,
              icon: Icons.repeat,
              iconColor: Colors.purple,
              title: '🔄 Múltiples Eventos',
              subtitle: 'Varios prints + 1 error',
              onTap: () => _generarMultiplesEventos(context),
            ),

            const SizedBox(height: 12),
            
            // Footer con advertencia
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ TEMPORAL - Eliminar después de pruebas',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.1),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Icon(Icons.play_arrow, color: Colors.grey[400]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  // 1. Print de prueba (reordenado al inicio)
  void _generarPrint(BuildContext context) {
    debugPrint('🧪 PRUEBA: Print simple - ${DateTime.now()}');
    debugPrint('📱 PRUEBA: Probando captura de debugPrint');
    debugPrint('✅ PRUEBA: Si ves esto, la captura funciona');
    print('🖨️ PRUEBA: Mensaje con print() normal');
    _mostrarMensaje(context, 'Prints enviados - Revisa logs arriba', Colors.green);
  }

  // 2. Error simple - siempre funciona
  void _generarErrorSimple(BuildContext context) {
    try {
      debugPrint('🧪 PRUEBA: Generando error simple...');
      throw Exception(
        '💥 Error de prueba generado a las ${DateTime.now().toLocal()}',
      );
    } catch (e) {
      debugPrint('❌ Error simple capturado: $e');
      _mostrarMensaje(context, 'Error simple generado', Colors.red);
    }
  }

  // 3. Error de base de datos
  Future<void> _generarErrorBD(BuildContext context) async {
    try {
      debugPrint('🧪 PRUEBA: Intentando query a tabla inexistente...');
      final db = await DatabaseService.database;
      // Esto va a fallar porque la tabla no existe
      await db.rawQuery('SELECT * FROM tabla_que_no_existe_para_prueba');
    } catch (e) {
      debugPrint('💾 Error de BD capturado: $e');
      _mostrarMensaje(context, 'Error de BD generado', Colors.blue);
    }
  }

  // 4. Error de red
  Future<void> _generarErrorRed(BuildContext context) async {
    try {
      debugPrint('🧪 PRUEBA: Intentando conexión a URL inválida...');
      // Intentar conectar a una URL que no existe
      final response = await http
          .get(Uri.parse('http://sitio-que-no-existe-para-pruebas.com/test'))
          .timeout(Duration(seconds: 3));
      debugPrint('Response: ${response.body}');
    } catch (e) {
      debugPrint('🌐 Error de red capturado: $e');
      _mostrarMensaje(context, 'Error de red generado', Colors.indigo);
    }
  }

  // 5. Múltiples eventos - NUEVO
  void _generarMultiplesEventos(BuildContext context) {
    debugPrint('🔄 PRUEBA: Iniciando múltiples eventos...');
    
    // Generar varios prints
    for (int i = 1; i <= 3; i++) {
      debugPrint('� EVENTO $i: Mensaje múltiple #$i');
    }
    
    // Generar un error después de los prints
    Future.delayed(Duration(milliseconds: 500), () {
      try {
        debugPrint('🧪 PRUEBA: Generando error en evento múltiple...');
        throw Exception('🔄 Error en secuencia múltiple - Evento final');
      } catch (e) {
        debugPrint('❌ Error múltiple capturado: $e');
      }
    });
    
    _mostrarMensaje(context, 'Múltiples eventos enviados', Colors.purple);
  }

  // Helper para mostrar mensajes
  void _mostrarMensaje(BuildContext context, String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('✅ $mensaje - Revisa los logs arriba'),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
