import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lacalera/services/database_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class SecretScreen extends StatefulWidget {
  const SecretScreen({super.key});

  @override
  State<SecretScreen> createState() => _SecretScreenState();
}

class _SecretScreenState extends State<SecretScreen> {
  List<String> _logs = [];
  Map<String, dynamic> _systemInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeveloperInfo();
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
    _logs = [
      '[${DateTime.now().toIso8601String()}] Modo desarrollador iniciado',
      '[INFO] Sistema de logs activo',
      '[DEBUG] Aplicación en modo debug',
    ];

    try {
      // Obtener estadísticas de la base de datos
      final pessoas = await DatabaseService.getPeople();
      _logs.add('[DB] Total de registros: ${pessoas.length}');

      final enviados = pessoas.where((p) => p['enviadaNube'] == 1).length;
      final pendientes = pessoas.length - enviados;
      _logs.add('[DB] Enviados: $enviados, Pendientes: $pendientes');

      // Verificar archivos de fotos
      int fotosExistentes = 0;
      int fotosFaltantes = 0;

      for (final persona in pessoas) {
        if (persona['fotoDniFrente'] != null) {
          if (await File(persona['fotoDniFrente']).exists()) {
            fotosExistentes++;
          } else {
            fotosFaltantes++;
          }
        }
        if (persona['fotoDniReverso'] != null) {
          if (await File(persona['fotoDniReverso']).exists()) {
            fotosExistentes++;
          } else {
            fotosFaltantes++;
          }
        }
      }

      _logs.add('[FILES] Fotos existentes: $fotosExistentes');
      _logs.add('[FILES] Fotos faltantes: $fotosFaltantes');
    } catch (e) {
      _logs.add('[ERROR] Error en análisis: $e');
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
          '• Datos de sesión\n\n'
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
      try {
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todos los datos han sido eliminados'),
            backgroundColor: Colors.red,
          ),
        );

        await _loadDeveloperInfo();
      } catch (e) {
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
    final logsText = _logs.join('\n');
    Clipboard.setData(ClipboardData(text: logsText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copiados al portapapeles'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo Debug', style: TextStyle(color: Colors.white)),
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
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
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

                  // Logs del sistema
                  _buildSection(
                    'Logs del Sistema',
                    Icons.list_alt,
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_logs.length} entradas de log',
                                style: const TextStyle(color: Colors.grey),
                              ),
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
                          height: 200,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _logs.join('\n'),
                              style: const TextStyle(
                                color: Colors.green,
                                fontFamily: 'monospace',
                                fontSize: 12,
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
