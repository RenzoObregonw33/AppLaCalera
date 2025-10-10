import 'package:flutter/material.dart';

class LoadingDialog {
  static bool _isShowing = false;

  /// Muestra un diálogo de carga elegante
  static void mostrar(BuildContext context, {String? mensaje}) {
    if (_isShowing) return; // Prevenir múltiples diálogos
    
    _isShowing = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicador de progreso circular
              CircularProgressIndicator(
                color: Color(0xFF1565C0),
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              
              // Título principal
              Text(
                mensaje ?? 'Enviando candidato...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              
              // Descripción
              Text(
                'Verificando datos y subiendo fotos',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
            ],
          ),
        );
      },
    );
  }

  /// Muestra un diálogo de carga para registro de candidato
  static void mostrarRegistroCandidato(BuildContext context) {
    mostrar(context, mensaje: 'Registrando candidato');
  }

  /// Muestra un diálogo de carga para envío de datos
  static void mostrarEnvioDatos(BuildContext context) {
    mostrar(context, mensaje: 'Enviando a la nube');
  }

  /// Muestra un diálogo de carga para sincronización
  static void mostrarSincronizacion(BuildContext context) {
    mostrar(context, mensaje: 'Sincronizando datos');
  }

  /// Cierra el diálogo de carga actual
  static void cerrar(BuildContext context) {
    if (_isShowing) {
      _isShowing = false;
      Navigator.of(context).pop();
    }
  }

  /// Verifica si hay un diálogo de carga visible
  static bool get isShowing => _isShowing;
}

/// Widget personalizable para diálogo de carga
class CustomLoadingDialog extends StatelessWidget {
  final String titulo;
  final String? descripcion;
  final Color? colorPrimario;
  final bool mostrarBarraProgreso;
  final String? textoAdicional;

  const CustomLoadingDialog({
    Key? key,
    required this.titulo,
    this.descripcion,
    this.colorPrimario,
    this.mostrarBarraProgreso = true,
    this.textoAdicional,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = colorPrimario ?? Color(0xFF1565C0);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono animado
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: color,
                  strokeWidth: 4,
                ),
              ),
            ),
            SizedBox(height: 24),
            
            // Título
            Text(
              titulo,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            
            if (descripcion != null) ...[
              SizedBox(height: 12),
              Text(
                descripcion!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            if (mostrarBarraProgreso) ...[
              SizedBox(height: 20),
              LinearProgressIndicator(
                color: color,
                backgroundColor: Colors.grey[300],
                minHeight: 4,
              ),
            ],
            
            if (textoAdicional != null) ...[
              SizedBox(height: 16),
              Text(
                textoAdicional!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Muestra este diálogo personalizado
  static void mostrar(
    BuildContext context, {
    required String titulo,
    String? descripcion,
    Color? colorPrimario,
    bool mostrarBarraProgreso = true,
    String? textoAdicional,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CustomLoadingDialog(
          titulo: titulo,
          descripcion: descripcion,
          colorPrimario: colorPrimario,
          mostrarBarraProgreso: mostrarBarraProgreso,
          textoAdicional: textoAdicional,
        );
      },
    );
  }
}

/// Utilidades adicionales para diálogos de carga
class LoadingUtils {
  /// Ejecuta una función async mientras muestra un diálogo de carga
  static Future<T> ejecutarConCarga<T>(
    BuildContext context, {
    required Future<T> Function() funcion,
    String mensaje = 'Procesando...',
    String? descripcion,
  }) async {
    LoadingDialog.mostrar(context, mensaje: mensaje);
    
    try {
      final resultado = await funcion();
      LoadingDialog.cerrar(context);
      return resultado;
    } catch (e) {
      LoadingDialog.cerrar(context);
      rethrow;
    }
  }

  /// Muestra un diálogo de carga con tiempo específico
  static Future<void> mostrarPorTiempo(
    BuildContext context, {
    required Duration duracion,
    String mensaje = 'Procesando...',
  }) async {
    LoadingDialog.mostrar(context, mensaje: mensaje);
    await Future.delayed(duracion);
    LoadingDialog.cerrar(context);
  }
}