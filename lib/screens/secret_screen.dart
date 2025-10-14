import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SecretScreen extends StatefulWidget {
  const SecretScreen({super.key});

  // 🔸 VARIABLES ESTÁTICAS PARA EL LOGGING
  static final List<String> _appLogs = [];
  static bool _isCapturing = false;
  static void Function(String?, {int? wrapWidth})? _originalDebugPrint;
  static void Function(FlutterErrorDetails)? _originalErrorHandler;
  static void Function()? _updateUICallback;

  // 🔸 MÉTODO PARA AGREGAR LOGS PERSONALIZADOS DESDE CUALQUIER PARTE DE LA APP
  static void addCustomLog(String message) {
    if (_isCapturing) {
      final timestamp = DateTime.now().toIso8601String().substring(0, 19);
      _appLogs.add('[$timestamp] 🔸 $message');

      // Mantener solo los últimos 50 logs
      if (_appLogs.length > 50) {
        _appLogs.removeAt(0);
      }

      _updateUICallback?.call();
    }
  }

  // 🚨 MÉTODO ESPECÍFICO PARA ERRORES CAPTURADOS EN TRY-CATCH
  static void addErrorLog(String error, {String? context, StackTrace? stackTrace}) {
    if (_isCapturing) {
      final timestamp = DateTime.now().toIso8601String().substring(0, 19);
      String logMessage = '[$timestamp] 🚨 ERROR MANEJADO: $error';
      
      if (context != null) {
        logMessage += ' | Contexto: $context';
      }
      
      _appLogs.add(logMessage);
      
      if (stackTrace != null) {
        final stackLines = stackTrace.toString().split('\n').take(3).join('\n');
        _appLogs.add('[$timestamp] 📍 Stack: $stackLines');
      }

      // Mantener solo los últimos 50 logs
      while (_appLogs.length > 50) {
        _appLogs.removeAt(0);
      }

      _updateUICallback?.call();
    }
  }

  // 📦 MÉTODO PARA LOGS RAW FORMATEADOS (usado por ApiLogger)
  static void addRawLog(String formattedLog) {
    if (_isCapturing) {
      _appLogs.add(formattedLog);

      // Mantener solo los últimos 50 logs
      while (_appLogs.length > 50) {
        _appLogs.removeAt(0);
      }

      _updateUICallback?.call();
    }
  }

  // INICIAR CAPTURA DE LOGS
  static void startLogCapture() {
    if (_isCapturing) return;

    _isCapturing = true;
    _appLogs.clear();

    final timestamp = DateTime.now().toIso8601String().substring(0, 19);
    _appLogs.add('[$timestamp] === CAPTURA DE LOGS INICIADA ===');
    _appLogs.add('[$timestamp] 📋 QUÉ SE CAPTURA:');
    _appLogs.add('[$timestamp]   • Errores de Flutter (FlutterError)');
    _appLogs.add('[$timestamp]   • Mensajes de debugPrint()');
    _appLogs.add('[$timestamp]   • Excepciones no manejadas');
    _appLogs.add('[$timestamp]   • Errores de try-catch (con addErrorLog)');
    _appLogs.add('[$timestamp]   • Logs personalizados (con addCustomLog)');
    _appLogs.add('[$timestamp] 🎯 Estado: ACTIVO - Esperando eventos...');

    if (kDebugMode) {
      // Guardar el debugPrint original
      _originalDebugPrint = debugPrint;

      // Interceptar debugPrint
      debugPrint = (String? message, {int? wrapWidth}) {
        if (_isCapturing && message != null) {
          final timestamp = DateTime.now().toIso8601String().substring(0, 19);
          _appLogs.add('[$timestamp] 🖨️ PRINT: $message');

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

      // Interceptar errores de Flutter
      FlutterError.onError = (FlutterErrorDetails details) {
        if (_isCapturing) {
          final timestamp = DateTime.now().toIso8601String().substring(0, 19);
          final stackLines = details.stack
              .toString()
              .split('\n')
              .take(5)
              .join('\n');

          _appLogs.add(
            '[$timestamp] 💥 FLUTTER ERROR: ${details.exception}\n'
            '📍 Stack:\n$stackLines',
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

  // DETENER CAPTURA DE LOGS
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
  State<SecretScreen> createState() => _SecretScreenState();
}

class _SecretScreenState extends State<SecretScreen> {
  List<String> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Establecer callback para actualizar UI
    SecretScreen._updateUICallback = () {
      if (mounted) {
        setState(() {});
      }
    };
    // Iniciar captura automáticamente al abrir la pantalla
    SecretScreen.startLogCapture();
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    // Limpiar callback al destruir el widget
    SecretScreen._updateUICallback = null;
    super.dispose();
  }

  void _exportLogs() {
    final logsText = SecretScreen._appLogs.join('\n');
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
      SecretScreen._appLogs.clear();
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
    if (SecretScreen._isCapturing) {
      SecretScreen.stopLogCapture();
    } else {
      SecretScreen.startLogCapture();
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
            onPressed: () => setState(() {}),
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
                  // Control de captura
                  Card(
                    elevation: 2,
                    color: SecretScreen._isCapturing ? Colors.green[50] : Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            SecretScreen._isCapturing
                                ? Icons.play_circle_filled
                                : Icons.stop_circle,
                            color: SecretScreen._isCapturing ? Colors.green : Colors.red,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Captura de Logs: ${SecretScreen._isCapturing ? "ACTIVA" : "DETENIDA"}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: SecretScreen._isCapturing
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                Text(
                                  SecretScreen._isCapturing
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
                              SecretScreen._isCapturing ? Icons.stop : Icons.play_arrow,
                            ),
                            label: Text(SecretScreen._isCapturing ? 'Detener' : 'Iniciar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SecretScreen._isCapturing
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
                                '${SecretScreen._appLogs.length} entradas - Captura: ${SecretScreen._isCapturing ? "ACTIVA" : "INACTIVA"}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: _exportLogs,
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Copiar'),
                                ),
                                TextButton.icon(
                                  onPressed: _clearLogs,
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: const Text('Limpiar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 400,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: SecretScreen._appLogs.isEmpty
                              ? const Center(
                                  child: Text(
                                    '📱 Esperando errores...\n\n'
                                    '💡 Cómo generar logs:\n'
                                    '• Desconecta internet y haz login\n'
                                    '• Registra un DNI que ya existe\n'
                                    '• Usa SecretScreen.addErrorLog() en try-catch\n'
                                    '• Usa SecretScreen.addCustomLog() para info',
                                    style: TextStyle(color: Colors.green, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: SecretScreen._appLogs.length,
                                  itemBuilder: (context, index) {
                                    final log = SecretScreen._appLogs[index];
                                    Color logColor = Colors.green[300]!;
                                    
                                    if (log.contains('ERROR') || log.contains('🚨')) {
                                      logColor = Colors.red[300]!;
                                    } else if (log.contains('🔸')) {
                                      logColor = Colors.blue[300]!;
                                    } else if (log.contains('PRINT') || log.contains('🖨️')) {
                                      logColor = Colors.yellow[300]!;
                                    }
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 1),
                                      child: Text(
                                        log,
                                        style: TextStyle(
                                          color: logColor,
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    );
                                  },
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
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }
}