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
  static void addErrorLog(
    String error, {
    String? context,
    StackTrace? stackTrace,
  }) {
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
    // NO limpiar logs existentes - solo agregar mensaje de inicio

    final timestamp = DateTime.now().toIso8601String().substring(0, 19);
    /*_appLogs.add('[$timestamp] === CAPTURA DE LOGS INICIADA ===');
    _appLogs.add('[$timestamp] 📋 QUÉ SE CAPTURA:');
    _appLogs.add('[$timestamp]   • Errores de Flutter (FlutterError)');
    _appLogs.add('[$timestamp]   • Mensajes de debugPrint()');
    _appLogs.add('[$timestamp]   • Excepciones no manejadas');
    _appLogs.add('[$timestamp]   • Errores de try-catch (con addErrorLog)');
    _appLogs.add('[$timestamp]   • Logs personalizados (con addCustomLog)'); */
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

  // 🧹 MÉTODO PARA LIMPIAR LOGS MANUALMENTE (botón "Limpiar")
  static void clearAllLogs() {
    _appLogs.clear();

    // Solo limpiar logs, NO afectar el estado de captura
    // La captura sigue activa si estaba activa

    _updateUICallback?.call();
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
    // YA NO iniciar captura aquí - se inicia automáticamente con los 7 toques
    // SecretScreen.startLogCapture(); ← REMOVIDO
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Modo Debug',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF1565C0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.refresh, color: Colors.white, size: 20),
              ),
              onPressed: () => setState(() {}),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1565C0)),
                  SizedBox(height: 16),
                  Text(
                    'Cargando modo debug...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Panel de control de captura
                  _buildCaptureControlPanel(),

                  SizedBox(height: 20),

                  // Panel de logs
                  _buildLogsPanel(),
                ],
              ),
            ),
    );
  }

  Widget _buildCaptureControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SecretScreen._isCapturing
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.settings,
                    color: SecretScreen._isCapturing
                        ? Colors.green
                        : Colors.red,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Control de Captura',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SecretScreen._isCapturing
                    ? Colors.green[50]
                    : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SecretScreen._isCapturing
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SecretScreen._isCapturing
                          ? Colors.green
                          : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      SecretScreen._isCapturing
                          ? Icons.play_circle_filled
                          : Icons.stop_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Captura: ${SecretScreen._isCapturing ? "ACTIVA" : "DETENIDA"}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: SecretScreen._isCapturing
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          SecretScreen._isCapturing
                              ? 'Registrando logs en tiempo real'
                              : 'Presiona el botón para activar',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _toggleCapture,
                    icon: Icon(
                      SecretScreen._isCapturing ? Icons.stop : Icons.play_arrow,
                      size: 18,
                    ),
                    label: Text(
                      SecretScreen._isCapturing ? 'Detener' : 'Iniciar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SecretScreen._isCapturing
                          ? Colors.red
                          : Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
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

  Widget _buildLogsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.terminal, color: Colors.blue, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  'Terminal de Logs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${SecretScreen._appLogs.length} entradas',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportLogs,
                    icon: Icon(Icons.copy, size: 16),
                    label: Text('Copiar Todo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearLogs,
                    icon: Icon(Icons.delete_outline, size: 16),
                    label: Text('Limpiar Todo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              height: 400,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SecretScreen._appLogs.isEmpty
                  ? _buildEmptyLogsState()
                  : _buildLogsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLogsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.code, size: 48, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Sin logs registrados',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Los logs aparecerán aquí en tiempo real cuando la captura esté activa',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Cómo generar logs:',
                  style: TextStyle(
                    color: Colors.yellow[300],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                ...[
                  '• Registra un candidato',
                  '• Desconecta internet y prueba login',
                  '• Usa el widget de pruebas',
                  '• Cualquier error automático',
                ].map(
                  (tip) => Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      tip,
                      style: TextStyle(color: Colors.grey[300], fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: SecretScreen._appLogs.length,
      itemBuilder: (context, index) {
        final log = SecretScreen._appLogs[index];
        return _buildLogEntry(log, index);
      },
    );
  }

  Widget _buildLogEntry(String log, int index) {
    Color logColor = Color(0xFF4CAF50); // Verde por defecto
    Color backgroundColor = Colors.transparent;
    IconData? prefixIcon;

    // Determinar color y estilo según el tipo de log
    if (log.contains('ERROR') || log.contains('🚨')) {
      logColor = Color(0xFFFF5252);
      backgroundColor = Color(0xFFFF5252).withOpacity(0.1);
      prefixIcon = Icons.error;
    } else if (log.contains('🔸') || log.contains('INFO')) {
      logColor = Color(0xFF2196F3);
      backgroundColor = Color(0xFF2196F3).withOpacity(0.1);
      prefixIcon = Icons.info;
    } else if (log.contains('PRINT') || log.contains('🖨️')) {
      logColor = Color(0xFFFFC107);
      backgroundColor = Color(0xFFFFC107).withOpacity(0.1);
      prefixIcon = Icons.print;
    } else if (log.contains('API') || log.contains('🌐')) {
      logColor = Color(0xFF9C27B0);
      backgroundColor = Color(0xFF9C27B0).withOpacity(0.1);
      prefixIcon = Icons.api;
    } else if (log.contains('INICIADA') || log.contains('DETENIDA')) {
      logColor = Color(0xFF607D8B);
      backgroundColor = Color(0xFF607D8B).withOpacity(0.1);
      prefixIcon = Icons.play_arrow;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: logColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, color: logColor, size: 16),
            SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              log,
              style: TextStyle(
                color: logColor,
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: logColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '#${index + 1}',
              style: TextStyle(
                color: logColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
