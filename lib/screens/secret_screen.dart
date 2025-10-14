import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lacalera/services/database_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lacalera/widgets/error_test_widget.dart';

class SecretScreen extends StatefulWidget {
  const SecretScreen({super.key});

  @override
  State<SecretScreen> createState() => _SecretScreenState();
}

class _SecretScreenState extends State<SecretScreen> {
  static final List<String> _appLogs = [];
  static bool _isCapturing = false;
  static void Function(String?, {int? wrapWidth})? _originalDebugPrint;
  static void Function(FlutterErrorDetails)? _originalErrorHandler;
  static void Function()? _updateUICallback;

  List<String> _logs = [];
  Map<String, dynamic> _systemInfo = {};
  bool _isLoading = true;

  // Iniciar captura de logs (solo cuando se activa el modo debug)
  static void startLogCapture() {
    if (_isCapturing) return;

    _isCapturing = true;
    _appLogs.clear();

    final timestamp = DateTime.now().toIso8601String().substring(0, 19);
    _appLogs.add('[$timestamp] === CAPTURA DE LOGS INICIADA ===');

    if (kDebugMode) {
      // Guardar el debugPrint original
      _originalDebugPrint = debugPrint;

      // Interceptar debugPrint
      debugPrint = (String? message, {int? wrapWidth}) {
        if (_isCapturing && message != null) {
          final timestamp = DateTime.now().toIso8601String().substring(0, 19);
          _appLogs.add('[$timestamp] PRINT: $message');

          // Mantener solo los últimos 50 logs
          if (_appLogs.length > 50) {
            _appLogs.removeAt(0);
          }

          // Actualizar UI en tiempo real
          _updateUICallback?.call();
        }

        // Llamar al debugPrint original
        _originalDebugPrint?.call(message, wrapWidth: wrapWidth);
      };

      // Guardar el manejador de errores original
      _originalErrorHandler = FlutterError.onError;

      // Interceptar errores no manejados con detalles completos
      FlutterError.onError = (FlutterErrorDetails details) {
        if (_isCapturing) {
          final timestamp = DateTime.now().toIso8601String().substring(0, 19);

          // Capturar error completo con stack trace y números de línea
          final error = details.exception.toString();
          final context = details.context?.toString() ?? 'Unknown context';
          final library = details.library ?? 'Unknown library';

          _appLogs.add(
            '[$timestamp] ==================== ERROR ====================',
          );
          _appLogs.add('[$timestamp] LIBRARY: $library');
          _appLogs.add('[$timestamp] CONTEXT: $context');
          _appLogs.add('[$timestamp] ERROR: $error');

          // Stack trace completo con números de línea
          if (details.stack != null) {
            _appLogs.add('[$timestamp] STACK TRACE:');
            final stackLines = details.stack.toString().split('\n');
            for (int i = 0; i < stackLines.length && i < 10; i++) {
              if (stackLines[i].trim().isNotEmpty) {
                _appLogs.add('[$timestamp]   ${stackLines[i].trim()}');
              }
            }
          }

          _appLogs.add(
            '[$timestamp] ================================================',
          );

          // Mantener límite de logs
          while (_appLogs.length > 50) {
            _appLogs.removeAt(0);
          }

          // Actualizar UI en tiempo real
          _updateUICallback?.call();
        }

        // Llamar al manejador original
        _originalErrorHandler?.call(details);
      };
    }
  }

  // Detener captura de logs
  static void stopLogCapture() {
    if (!_isCapturing) return;

    final timestamp = DateTime.now().toIso8601String().substring(0, 19);
    _appLogs.add('[$timestamp] === CAPTURA DE LOGS DETENIDA ===');

    _isCapturing = false;

    // Restaurar handlers originales
    if (_originalDebugPrint != null) {
      debugPrint = _originalDebugPrint!;
    }
    if (_originalErrorHandler != null) {
      FlutterError.onError = _originalErrorHandler;
    }
  }

  @override
  void initState() {
    super.initState();
    // Establecer callback para actualizar UI
    _updateUICallback = () {
      if (mounted) {
        setState(() {});
      }
    };
    // Iniciar captura automáticamente al abrir la pantalla
    startLogCapture();
    _loadDeveloperInfo();
  }

  @override
  void dispose() {
    // Limpiar callback al destruir el widget
    _updateUICallback = null;
    super.dispose();
  }

  Future<void> _loadDeveloperInfo() async {
    setState(() => _isLoading = true);

    try {
      await _loadSystemInfo();
      await _loadRecentLogs();
    } catch (e) {
      _logs.add('Error cargando información: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadSystemInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final directory = await getApplicationDocumentsDirectory();

    _systemInfo = {
      'App Version': '1.0.0',
      'Flutter Version': 'Flutter 3.x',
      'Platform': Platform.operatingSystem,
      'Platform Version': Platform.operatingSystemVersion,
      'Documents Path': directory.path,
      'SharedPreferences Keys': prefs.getKeys().length.toString(),
      'Database Status': await _getDatabaseStatus(),
      'Memoria RAM': await _getMemoryInfo(),
      'Captura Activa': _isCapturing ? 'SÍ' : 'NO',
      'Total Logs Capturados': _appLogs.length.toString(),
      'Timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<String> _getDatabaseStatus() async {
    try {
      final db = await DatabaseService.database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      return 'OK - ${tables.length} tablas';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> _getMemoryInfo() async {
    try {
      // Información básica del proceso
      final info = ProcessInfo.currentRss;
      return '${(info / 1024 / 1024).toStringAsFixed(2)} MB';
    } catch (e) {
      return 'No disponible';
    }
  }

  Future<void> _loadRecentLogs() async {
    final timestamp = DateTime.now().toIso8601String().substring(0, 19);

    _logs = [
      '[$timestamp] === SESIÓN DE DIAGNÓSTICO INICIADA ===',
      '[$timestamp] Modo errores activado por usuario',
      '[$timestamp] Analizando estado del sistema...',
    ];

    try {
      // Agregar logs capturados en tiempo real
      if (_appLogs.isNotEmpty) {
        _logs.add('[$timestamp] === LOGS EN TIEMPO REAL ===');
        _logs.addAll(_appLogs);
      } else {
        _logs.add(
          '[$timestamp] [INFO] Sin errores capturados hasta el momento',
        );
      }

      // Separador para análisis del sistema
      _logs.add('[$timestamp] === ANÁLISIS DEL SISTEMA ===');

      // Obtener estadísticas de la base de datos
      final pessoas = await DatabaseService.getPeople();
      _logs.add('[$timestamp] [DB] Total de registros: ${pessoas.length}');

      final enviados = pessoas.where((p) => p['enviadaNube'] == 1).length;
      final pendientes = pessoas.length - enviados;
      _logs.add(
        '[$timestamp] [DB] Enviados: $enviados, Pendientes: $pendientes',
      );

      _logs.add('[$timestamp] [OK] Análisis de base de datos completado');
    } catch (e) {
      _logs.add('[$timestamp] [ERROR] Error en análisis del sistema: $e');
    }
  }

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ ADVERTENCIA'),
        content: const Text(
          'Esto eliminará TODOS los datos de la aplicación:\n\n'
          '• Todos los registros de candidatos\n'
          '• Todas las fotos\n'
          '• Configuraciones de usuario\n'
          '• Datos de sesión\n'
          '• Logs capturados\n\n'
          '¿Está COMPLETAMENTE seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINAR TODO'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final timestamp = DateTime.now().toIso8601String().substring(0, 19);

      try {
        // Limpiar logs capturados
        _appLogs.clear();

        // Eliminar base de datos
        final db = await DatabaseService.database;
        await db.execute('DELETE FROM personas');

        // Eliminar SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Eliminar directorio de fotos
        final directory = await getApplicationDocumentsDirectory();
        final fotosDir = Directory('${directory.path}/fotos');
        if (await fotosDir.exists()) {
          await fotosDir.delete(recursive: true);
        }

        _logs.add(
          '[$timestamp] [SYSTEM] Todos los datos eliminados correctamente',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todos los datos han sido eliminados'),
            backgroundColor: Colors.red,
          ),
        );

        await _loadDeveloperInfo();
      } catch (e) {
        _logs.add('[$timestamp] [ERROR] Fallo al eliminar datos: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error eliminando datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exportLogs() {
    final logsText = _appLogs.join('\n');
    Clipboard.setData(ClipboardData(text: logsText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copiados al portapapeles'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearLogs() {
    setState(() {
      _appLogs.clear();
      _logs.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs limpiados'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _toggleCapture() {
    if (_isCapturing) {
      stopLogCapture();
    } else {
      startLogCapture();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Errores', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDeveloperInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del sistema
                  _buildSection(
                    'Información del Sistema',
                    Icons.info_outline,
                    Column(
                      children: _systemInfo.entries
                          .map((entry) => _buildInfoRow(entry.key, entry.value))
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Widget de pruebas de errores (TEMPORAL)
                  const ErrorTestWidget(),

                  const SizedBox(height: 20),

                  // Control de captura
                  Card(
                    elevation: 2,
                    color: _isCapturing ? Colors.green[50] : Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _isCapturing
                                ? Icons.play_circle_filled
                                : Icons.stop_circle,
                            color: _isCapturing ? Colors.green : Colors.red,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Captura de Logs: ${_isCapturing ? "ACTIVA" : "DETENIDA"}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _isCapturing
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                Text(
                                  _isCapturing
                                      ? 'Capturando errores en tiempo real...'
                                      : 'Presiona para activar captura',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _toggleCapture,
                            icon: Icon(
                              _isCapturing ? Icons.stop : Icons.play_arrow,
                            ),
                            label: Text(_isCapturing ? 'Detener' : 'Iniciar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isCapturing
                                  ? Colors.red
                                  : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Logs del sistema
                  _buildSection(
                    'Logs de Errores en Tiempo Real',
                    Icons.bug_report,
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_appLogs.length} entradas - Captura: ${_isCapturing ? "ACTIVA" : "INACTIVA"}',
                                style: TextStyle(
                                  color: _isCapturing
                                      ? Colors.green
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _clearLogs,
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Limpiar'),
                            ),
                            TextButton.icon(
                              onPressed: _exportLogs,
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copiar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 350,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isCapturing ? Colors.green : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: SingleChildScrollView(
                            reverse: true,
                            child: Text(
                              _appLogs.isEmpty
                                  ? '[Sin logs capturados]'
                                  : _appLogs.join('\n'),
                              style: const TextStyle(
                                color: Colors.green,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Acciones de desarrollador
                  _buildSection(
                    'Acciones de Desarrollador',
                    Icons.build,
                    Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.refresh,
                            color: Colors.blue,
                          ),
                          title: const Text('Recargar información'),
                          subtitle: const Text('Actualizar todos los datos'),
                          onTap: _loadDeveloperInfo,
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          title: const Text('Eliminar todos los datos'),
                          subtitle: const Text('⚠️ Acción irreversible'),
                          onTap: _clearAllData,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.black),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
