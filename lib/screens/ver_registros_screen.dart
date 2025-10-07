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
  List<bool> _seleccionadosFaltanEnviar = [];
  List<bool> _seleccionadosYaEnviados = [];
  bool _seleccionarTodosFaltanEnviar = false;
  bool _seleccionarTodosYaEnviados = false;
  bool _isLoading = true;
  int _organiId = 0;
  bool _filtroEnviados = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _cargarRegistros();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 🎯 PRIORIZAR EL organi_id YA SELECCIONADO
      final organiIdSeleccionado = prefs.getInt('organi_id');

      print('🔍 ===== CARGANDO DATOS USUARIO =====');
      print('🏢 Organi_ID ya seleccionado: $organiIdSeleccionado');

      if (organiIdSeleccionado != null && organiIdSeleccionado != 0) {
        // Si ya hay una organización seleccionada, usarla
        setState(() {
          _organiId = organiIdSeleccionado;
        });
        print('✅ Usando organi_id seleccionado: $_organiId');
      } else {
        // Solo si no hay organización seleccionada, usar la primera
        final userJson = prefs.getString('user_data');
        if (userJson != null) {
          final userData = jsonDecode(userJson);
          if (userData['organizaciones'] != null &&
              userData['organizaciones'].isNotEmpty) {
            setState(() {
              _organiId = userData['organizaciones'][0]['organi_id'] ?? 0;
            });
            await prefs.setInt('organi_id', _organiId);
            print(
              '⚠️ No había organi_id seleccionado, usando el primero: $_organiId',
            );
          }
        }
      }
      print('🔍 ===================================');
    } catch (e) {
      print("❌ Error cargando datos de usuario: $e");
    }
  }

  // Verificar conexión a internet
  Future<bool> _verificarConexion() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _enviarSeleccionados() async {
    // Verificar conexión a internet primero
    if (!await _verificarConexion()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sin conexión a internet. Verifica tu conexión.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final seleccionados = _getSeleccionadosActuales();

    if (seleccionados.every((element) => !element)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione al menos un registro para enviar'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    int enviados = 0;
    int errores = 0;
    List<String> mensajesError = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enviando registros'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'Procesando ${seleccionados.where((s) => s).length} registros...',
            ),
          ],
        ),
      ),
    );

    for (int i = 0; i < _registros.length; i++) {
      if (seleccionados[i]) {
        final registro = _registros[i];
        String? fotoFrontBase64;
        String? fotoReverseBase64;

        try {
          if (registro['fotoDniFrente'] != null &&
              registro['fotoDniFrente'].toString().isNotEmpty) {
            final file = File(registro['fotoDniFrente']);

            // Verificar que el archivo existe
            if (!await file.exists()) {
              print(
                '❌ Archivo de foto frontal no existe: ${registro['fotoDniFrente']}',
              );
              errores++;
              mensajesError.add(
                '${registro['dni']}: Foto frontal no encontrada',
              );
              continue;
            }

            final bytes = await file.readAsBytes();

            // Validar tamaño de imagen (máximo 2MB)
            if (bytes.length > 2 * 1024 * 1024) {
              print('⚠️ Imagen frente muy grande: ${bytes.length} bytes');
              // Crear una versión más pequeña
              final smallerBytes = bytes
                  .take(1024 * 1024)
                  .toList(); // Limitar a 1MB
              fotoFrontBase64 = base64Encode(smallerBytes);
            } else {
              fotoFrontBase64 = base64Encode(bytes);
            }
          }

          if (registro['fotoDniReverso'] != null &&
              registro['fotoDniReverso'].toString().isNotEmpty) {
            final file = File(registro['fotoDniReverso']);

            // Verificar que el archivo existe
            if (!await file.exists()) {
              print(
                '❌ Archivo de foto reverso no existe: ${registro['fotoDniReverso']}',
              );
              errores++;
              mensajesError.add(
                '${registro['dni']}: Foto reverso no encontrada',
              );
              continue;
            }

            final bytes = await file.readAsBytes();

            // Validar tamaño de imagen (máximo 2MB)
            if (bytes.length > 2 * 1024 * 1024) {
              print('⚠️ Imagen reverso muy grande: ${bytes.length} bytes');
              // Crear una versión más pequeña
              final smallerBytes = bytes
                  .take(1024 * 1024)
                  .toList(); // Limitar a 1MB
              fotoReverseBase64 = base64Encode(smallerBytes);
            } else {
              fotoReverseBase64 = base64Encode(bytes);
            }
          }
        } catch (e) {
          print('❌ Error leyendo fotos: $e');
        }

        // 🎯 USAR SIEMPRE LA ORGANIZACIÓN ACTUALMENTE SELECCIONADA
        int idOrg = _organiId; // No usar el del registro, sino el actual

        print('📤 ===== ENVIANDO REGISTRO A API =====');
        print('📋 DNI: ${registro['dni']}');
        print('👤 Nombres: ${registro['nombres']}');
        print('👤 Apellidos: ${registro['apellidos']}');
        print('📱 Teléfono: ${registro['telefono']}');
        print('📧 Email: ${registro['email']}');
        print('🏠 Dirección: ${registro['direccion']}');
        print('� ID del registro: ${registro['id']}');
        print(
          '�🏢 Organi_ID del registro (IGNORADO): ${registro['organi_id']}',
        );
        print('🏢 Organi_ID del usuario actual (USADO): $_organiId');
        print('🎯 ID final a enviar: $idOrg');
        print(
          '📷 Foto frontal: ${fotoFrontBase64 != null ? 'SÍ (${fotoFrontBase64.length} caracteres)' : 'NO'}',
        );
        print(
          '📷 Foto reverso: ${fotoReverseBase64 != null ? 'SÍ (${fotoReverseBase64.length} caracteres)' : 'NO'}',
        );
        print('🗓️ Fecha creación: ${registro['fechaCreacion']}');
        print(
          '✅ Enviado anteriormente: ${registro['enviadaNube'] == 1 ? 'SÍ' : 'NO'}',
        );
        print('📤 ====================================');

        final response = await ApiService.sendPersonToApi(
          document: registro['dni'] ?? '',
          id: idOrg,
          movil: registro['telefono'] ?? '',
          photoFrontBase64: fotoFrontBase64,
          photoReverseBase64: fotoReverseBase64,
        );

        print('📥 ===== RESPUESTA DE LA API =====');
        print('✅ Success: ${response['success']}');
        print('📄 Response completa: $response');
        print('📥 ===============================');

        if (response['success'] == true) {
          enviados++;
          print('✅ Marcando registro ${registro['id']} como enviado');
          await DatabaseService.marcarEnviado(registro['id']);
        } else {
          errores++;
          print(
            '❌ Error enviando registro ${registro['dni']}: ${response['message'] ?? 'Error desconocido'}',
          );
          mensajesError.add(
            '${registro['dni']}: ${response['message'] ?? 'Error desconocido'}',
          );
        }
      }
    }

    Navigator.pop(context);

    // 🔄 RECARGAR REGISTROS para mostrar cambios
    await _cargarRegistros();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enviados > 0
              ? errores > 0
                    ? 'Se enviaron $enviados registros. $errores con errores.'
                    : 'Se enviaron los datos correctamente'
              : 'No se enviaron los datos',
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: enviados > 0 ? Colors.green : Colors.red,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _cargarRegistros() async {
    setState(() {
      _isLoading = true;
    });

    print('🔄 ===== CARGANDO REGISTROS DESDE BASE DE DATOS =====');
    print('🏢 OrganiId actual: $_organiId');

    final List<Map<String, dynamic>> registros =
        await DatabaseService.getPeople();

    print('📊 ===== DATOS CARGADOS =====');
    print('📍 Total de registros encontrados: ${registros.length}');

    // Mostrar cada registro en detalle
    for (int i = 0; i < registros.length; i++) {
      final registro = registros[i];
      print('📋 Registro ${i + 1}:');
      print('   ID: ${registro['id']}');
      print('   DNI: ${registro['dni']}');
      print('   Nombres: ${registro['nombres']}');
      print('   Apellidos: ${registro['apellidos']}');
      print('   Teléfono: ${registro['telefono']}');
      print('   Email: ${registro['email']}');
      print('   Dirección: ${registro['direccion']}');
      print('   OrganiId: ${registro['organi_id']}');
      print(
        '   Enviado a la nube: ${registro['enviadaNube'] == 1 ? 'SÍ' : 'NO'}',
      );
      print('   Fecha creación: ${registro['fechaCreacion']}');
      print(
        '   Imagen: ${registro['rutaImagen'] != null ? 'SÍ tiene imagen' : 'NO tiene imagen'}',
      );
      print('   ________________');
    }

    // Filtrar por organización actual
    final registrosFiltrados = registros
        .where((registro) => registro['organi_id'] == _organiId)
        .toList();

    print('🎯 ===== REGISTROS FILTRADOS POR ORGANIZACIÓN =====');
    print('🏢 Mostrando solo registros de organización: $_organiId');
    print('📊 Registros de esta organización: ${registrosFiltrados.length}');

    setState(() {
      _registros = registrosFiltrados;
      _seleccionadosFaltanEnviar = List<bool>.filled(
        registrosFiltrados.length,
        false,
      );
      _seleccionadosYaEnviados = List<bool>.filled(
        registrosFiltrados.length,
        false,
      );
      _seleccionarTodosFaltanEnviar = false;
      _seleccionarTodosYaEnviados = false;
      _isLoading = false;
    });

    print('✅ Registros cargados y estado actualizado');
  }

  void _seleccionarTodosRegistros(bool? value) {
    setState(() {
      if (_filtroEnviados) {
        _seleccionarTodosYaEnviados = value ?? false;
        final registrosFiltrados = _getRegistrosFiltrados();
        for (int i = 0; i < _seleccionadosYaEnviados.length; i++) {
          if (registrosFiltrados.contains(i)) {
            _seleccionadosYaEnviados[i] = _seleccionarTodosYaEnviados;
          } else {
            _seleccionadosYaEnviados[i] = false;
          }
        }
      } else {
        _seleccionarTodosFaltanEnviar = value ?? false;
        final registrosFiltrados = _getRegistrosFiltrados();
        for (int i = 0; i < _seleccionadosFaltanEnviar.length; i++) {
          if (registrosFiltrados.contains(i)) {
            _seleccionadosFaltanEnviar[i] = _seleccionarTodosFaltanEnviar;
          } else {
            _seleccionadosFaltanEnviar[i] = false;
          }
        }
      }
    });
  }

  void _toggleSeleccion(int indexFiltrado) {
    final registrosFiltrados = _getRegistrosFiltrados();
    if (indexFiltrado < 0 || indexFiltrado >= registrosFiltrados.length) return;
    final realIndex = registrosFiltrados[indexFiltrado];

    setState(() {
      if (_filtroEnviados) {
        _seleccionadosYaEnviados[realIndex] =
            !_seleccionadosYaEnviados[realIndex];
        _seleccionarTodosYaEnviados = registrosFiltrados.every(
          (i) => _seleccionadosYaEnviados[i],
        );
      } else {
        _seleccionadosFaltanEnviar[realIndex] =
            !_seleccionadosFaltanEnviar[realIndex];
        _seleccionarTodosFaltanEnviar = registrosFiltrados.every(
          (i) => _seleccionadosFaltanEnviar[i],
        );
      }
    });
  }

  List<int> _getRegistrosFiltrados() {
    return _registros
        .asMap()
        .entries
        .where(
          (entry) => _filtroEnviados
              ? entry.value['enviadaNube'] == 1
              : entry.value['enviadaNube'] != 1,
        )
        .map((entry) => entry.key)
        .toList();
  }

  List<bool> _getSeleccionadosActuales() {
    return _filtroEnviados
        ? _seleccionadosYaEnviados
        : _seleccionadosFaltanEnviar;
  }

  bool _getSeleccionarTodosActual() {
    return _filtroEnviados
        ? _seleccionarTodosYaEnviados
        : _seleccionarTodosFaltanEnviar;
  }

  int _getCantidadSeleccionadosActual() {
    final seleccionados = _getSeleccionadosActuales();
    return seleccionados.where((s) => s).length;
  }

  Future<void> _eliminarSeleccionados() async {
    final seleccionados = _getSeleccionadosActuales();
    final seleccionadosCount = seleccionados.where((s) => s).length;

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
    final seleccionadosActuales = _getSeleccionadosActuales();

    for (int i = seleccionadosActuales.length - 1; i >= 0; i--) {
      if (seleccionadosActuales[i]) {
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

  bool _isSeleccionado(int realIndex) {
    if (_filtroEnviados) {
      return _seleccionadosYaEnviados[realIndex];
    } else {
      return _seleccionadosFaltanEnviar[realIndex];
    }
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
                _buildInfoRow(
                  'Fecha de Registro',
                  registro['fechaRegistro'] != null
                      ? registro['fechaRegistro']
                            .toString()
                            .substring(0, 16)
                            .replaceFirst('T', ' ')
                      : 'No disponible',
                  Icons.calendar_today,
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
                          'DNI Inhabilitado',
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
                  value.isNotEmpty ? value : 'No especificado',
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
        title: const Text('Candidatos', style: TextStyle(color: Colors.white)),
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
          // Filtro visual en el body Botones de filtro
          if (_registros.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _filtroEnviados == false
                            ? const Color(0xFF1565C0)
                            : Colors.grey[200],
                        foregroundColor: _filtroEnviados == false
                            ? Colors.white
                            : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _filtroEnviados = false;
                        });
                      },
                      child: const Text('Faltan enviar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _filtroEnviados == true
                            ? const Color(0xFF1565C0)
                            : Colors.grey[200],
                        foregroundColor: _filtroEnviados == true
                            ? Colors.white
                            : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _filtroEnviados = true;
                        });
                      },
                      child: const Text('Ya enviados'),
                    ),
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
                : Column(
                    children: [
                      // Panel de acciones solo para "Faltan enviar"
                      if (!_filtroEnviados)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _getSeleccionarTodosActual(),
                                onChanged: _seleccionarTodosRegistros,
                                activeColor: const Color(0xFF1565C0),
                              ),
                              const Text('Seleccionar todos'),
                              const Spacer(),
                              if (_getCantidadSeleccionadosActual() > 0)
                                Text(
                                  '${_getCantidadSeleccionadosActual()} seleccionados',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.cloud_upload,
                                  color: Colors.lightBlueAccent,
                                ),
                                onPressed: _enviarSeleccionados,
                                tooltip: 'Enviar seleccionados',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.grey,
                                ),
                                onPressed: _eliminarSeleccionados,
                                tooltip: 'Eliminar seleccionados',
                              ),
                            ],
                          ),
                        ),
                      // Panel de acciones solo para "Ya enviados"
                      if (_filtroEnviados)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _getSeleccionarTodosActual(),
                                onChanged: _seleccionarTodosRegistros,
                                activeColor: const Color(0xFF1565C0),
                              ),
                              const Text('Seleccionar todos'),
                              const Spacer(),
                              if (_getCantidadSeleccionadosActual() > 0)
                                Text(
                                  '${_getCantidadSeleccionadosActual()} seleccionados',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.grey,
                                ),
                                onPressed: _eliminarSeleccionados,
                                tooltip: 'Eliminar seleccionados',
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final registrosFiltrados = _getRegistrosFiltrados();
                            return ListView.builder(
                              itemCount: registrosFiltrados.length,
                              itemBuilder: (context, index) {
                                final realIndex = registrosFiltrados[index];
                                final registro = _registros[realIndex];
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
                                    color: registro['enviadaNube'] == 1
                                        ? Color(0xFFB2F7EF)
                                        : Colors.white,
                                    child: ListTile(
                                      leading: Checkbox(
                                        value: _isSeleccionado(realIndex),
                                        onChanged: (value) =>
                                            _toggleSeleccion(index),
                                        activeColor: const Color(0xFF1565C0),
                                      ),
                                      title: Text(
                                        '${registro['nombre']} ${registro['apellidoPaterno']} ',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                _mostrarDetallesCompletos(
                                                  realIndex,
                                                ),
                                            tooltip: 'Ver detalles',
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.grey,
                                            ),
                                            onPressed: () =>
                                                _eliminarRegistro(realIndex),
                                            tooltip: 'Eliminar',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
