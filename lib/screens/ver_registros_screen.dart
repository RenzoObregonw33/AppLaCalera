import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lacalera/services/database_services.dart';
import 'package:lacalera/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerRegistrosScreen extends StatefulWidget {
  const VerRegistrosScreen({super.key});

  @override
  State<VerRegistrosScreen> createState() => _VerRegistrosScreenState();
}

class _VerRegistrosScreenState extends State<VerRegistrosScreen> {
  List<Map<String, dynamic>> _registros = [];
  List<bool> _seleccionados = [];
  bool _seleccionarTodos = false;
  bool _isLoading = true;
  int _organiId = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _cargarRegistros();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');

      if (userJson != null) {
        final userData = jsonDecode(userJson);
        if (userData['organizaciones'] != null &&
            userData['organizaciones'].isNotEmpty) {
          setState(() {
            _organiId = userData['organizaciones'][0]['organi_id'] ?? 0;
          });
          // Guardar organi_id en SharedPreferences para uso futuro
          await prefs.setInt('organi_id', _organiId);
        }
      }
    } catch (e) {
      print("❌ Error cargando datos de usuario: $e");
    }
  }

  Future<void> _enviarSeleccionados() async {
    if (_seleccionados.every((element) => !element)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione al menos un registro para enviar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int enviados = 0;
    int errores = 0;
    String lastMessage = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enviando registros'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Procesando ${_seleccionados.where((s) => s).length} registros...',
            ),
          ],
        ),
      ),
    );

    for (int i = 0; i < _registros.length; i++) {
      if (_seleccionados[i]) {
        final registro = _registros[i];
        String? fotoFrontBase64;
        String? fotoReverseBase64;

        try {
          if (registro['fotoDniFrente'] != null &&
              registro['fotoDniFrente'].toString().isNotEmpty) {
            final bytes = await File(registro['fotoDniFrente']).readAsBytes();
            fotoFrontBase64 = base64Encode(bytes);
          }
          if (registro['fotoDniReverso'] != null &&
              registro['fotoDniReverso'].toString().isNotEmpty) {
            final bytes = await File(registro['fotoDniReverso']).readAsBytes();
            fotoReverseBase64 = base64Encode(bytes);
          }
        } catch (e) {
          print('❌ Error leyendo fotos: $e');
        }

        int idOrg = registro['organi_id'] ?? _organiId;

        final response = await ApiService.sendPersonToApi(
          document: registro['dni'] ?? '',
          id: idOrg,
          movil: registro['telefono'] ?? '',
          photoFrontBase64: fotoFrontBase64,
          photoReverseBase64: fotoReverseBase64,
        );

        lastMessage = response['message'] ?? '';
        if (response['success'] == true) {
          enviados++;
        } else {
          errores++;
        }
      }
    }

    Navigator.pop(context); // Cerrar diálogo de progreso

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✅ Enviados: $enviados, ❌ Errores: $errores'),
            if (lastMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Mensaje: $lastMessage',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        backgroundColor: enviados > 0 ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _cargarRegistros() async {
    setState(() {
      _isLoading = true;
    });

    final List<Map<String, dynamic>> registros =
        await DatabaseService.getPeople();
    setState(() {
      _registros = registros;
      _seleccionados = List<bool>.filled(registros.length, false);
      _seleccionarTodos = false;
      _isLoading = false;
    });
  }

  void _seleccionarTodosRegistros(bool? value) {
    setState(() {
      _seleccionarTodos = value ?? false;
      _seleccionados = List<bool>.filled(_registros.length, _seleccionarTodos);
    });
  }

  void _toggleSeleccion(int index) {
    setState(() {
      _seleccionados[index] = !_seleccionados[index];
      _seleccionarTodos = _seleccionados.every((s) => s);
    });
  }

  Future<void> _eliminarSeleccionados() async {
    final seleccionadosCount = _seleccionados.where((s) => s).length;
    if (seleccionadosCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione al menos un registro para eliminar'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar registros'),
        content: Text(
          '¿Está seguro de que desea eliminar $seleccionadosCount registro(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF1565C0)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final db = await DatabaseService.database;
    int eliminados = 0;

    for (int i = _seleccionados.length - 1; i >= 0; i--) {
      if (_seleccionados[i]) {
        await db.delete(
          'personas',
          where: 'id = ?',
          whereArgs: [_registros[i]['id']],
        );
        eliminados++;
      }
    }

    await _cargarRegistros();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$eliminados registro(s) eliminado(s) correctamente'),
        backgroundColor: Colors.black,
      ),
    );
  }

  Future<void> _eliminarRegistro(int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text(
          '¿Está seguro de que desea eliminar este registro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF1565C0)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final db = await DatabaseService.database;
    await db.delete(
      'personas',
      where: 'id = ?',
      whereArgs: [_registros[index]['id']],
    );
    await _cargarRegistros();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registro eliminado'),
        backgroundColor: Colors.black,
      ),
    );
  }

  void _mostrarDetallesCompletos(int index) {
    final registro = _registros[index];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Detalles Completos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Nombre', registro['nombre'], Icons.person),
                _buildInfoRow(
                  'Apellido',
                  registro['apellidoPaterno'],
                  Icons.person_outline,
                ),
                _buildInfoRow('DNI', registro['dni'], Icons.badge),
                _buildInfoRow('Teléfono', registro['telefono'], Icons.phone),
                _buildInfoRow(
                  'Modelo de Contrato',
                  registro['modeloContrato'],
                  Icons.work,
                ),

                if (registro['isBlacklisted'] == 1)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'DNI en lista negra',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Fotos del Documento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildImagePreviewDialog(
                      'Frente del DNI',
                      registro['fotoDniFrente'],
                    ),
                    _buildImagePreviewDialog(
                      'Reverso del DNI',
                      registro['fotoDniReverso'],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1565C0), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ?? 'No especificado',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewDialog(String title, String path) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _mostrarImagenCompleta(path, title),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: path.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(path), fit: BoxFit.cover),
                  )
                : Center(
                    child: Icon(Icons.photo, color: Colors.grey[400], size: 40),
                  ),
          ),
        ),
      ],
    );
  }

  void _mostrarImagenCompleta(String path, String title) {
    if (path.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black54,
              title: Text(title, style: const TextStyle(color: Colors.white)),
              centerTitle: true,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.file(File(path)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Postulantes Guardados',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFF1565C0),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarRegistros,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔥 NUEVO: Panel de controles en el body
          if (_registros.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  // Checkbox para seleccionar todos
                  Row(
                    children: [
                      Checkbox(
                        value: _seleccionarTodos,
                        onChanged: _seleccionarTodosRegistros,
                        activeColor: const Color(0xFF1565C0),
                      ),
                      const Text('Seleccionar todos'),
                    ],
                  ),

                  const Spacer(),

                  // Contador de seleccionados
                  if (_seleccionados.any((s) => s))
                    Text(
                      '${_seleccionados.where((s) => s).length} seleccionados',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),

                  const Spacer(),

                  // Botones de acción
                  Row(
                    children: [
                      // Botón Enviar
                      IconButton(
                        icon: const Icon(
                          Icons.cloud_upload,
                          color: Colors.lightBlueAccent,
                        ),
                        onPressed: _enviarSeleccionados,
                        tooltip: 'Enviar seleccionados',
                      ),

                      const SizedBox(width: 8),

                      // Botón Eliminar
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.grey),
                        onPressed: _eliminarSeleccionados,
                        tooltip: 'Eliminar seleccionados',
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Lista de registros
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                  )
                : _registros.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.list_alt,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay registros guardados',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _cargarRegistros,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Actualizar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _registros.length,
                    itemBuilder: (context, index) {
                      final registro = _registros[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Checkbox(
                              value: _seleccionados[index],
                              onChanged: (value) => _toggleSeleccion(index),
                              activeColor: const Color(0xFF1565C0),
                            ),
                            title: Text(
                              '${registro['nombre']} ${registro['apellidoPaterno']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DNI: ${registro['dni']}'),                      
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.info_outline,
                                    color: Color(0xFF1565C0),
                                  ),
                                  onPressed: () =>
                                      _mostrarDetallesCompletos(index),
                                  tooltip: 'Ver detalles',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => _eliminarRegistro(index),
                                  tooltip: 'Eliminar',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

}
