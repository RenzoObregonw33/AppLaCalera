import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lacalera/services/database_services.dart';

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

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    setState(() {
      _isLoading = true;
    });
    
    final List<Map<String, dynamic>> registros = await DatabaseService.getPeople();
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

  Future<void> _eliminarSeleccionados() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar registros'),
        content: Text('¿Está seguro de que desea eliminar ${_seleccionados.where((s) => s).length} registros?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF1565C0))),
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
    
    for (int i = _seleccionados.length - 1; i >= 0; i--) {
      if (_seleccionados[i]) {
        await db.delete(
          'personas',
          where: 'id = ?',
          whereArgs: [_registros[i]['id']],
        );
      }
    }
    
    await _cargarRegistros();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_seleccionados.where((s) => s).length} registros eliminados'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _eliminarRegistro(int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text('¿Está seguro de que desea eliminar este registro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF1565C0))),
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
        backgroundColor: Colors.green,
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Nombre', registro['nombre'], Icons.person),
                _buildInfoRow('Apellido', registro['apellidoPaterno'], Icons.person_outline),
                _buildInfoRow('DNI', registro['dni'], Icons.badge),
                _buildInfoRow('Teléfono', registro['telefono'], Icons.phone),
                _buildInfoRow('Modelo de Contrato', registro['modeloContrato'], Icons.work),
                
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
                          style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Fotos del Documento',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildImagePreviewDialog('Frente del DNI', registro['fotoDniFrente']),
                    _buildImagePreviewDialog('Reverso del DNI', registro['fotoDniReverso']),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(path), fit: BoxFit.cover),
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarImagenCompleta(String path, String title) {
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
        title: const Text('Registros Guardados', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFF1565C0),
        actions: [
          if (_registros.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.select_all, color: Colors.white),
              onPressed: () => _seleccionarTodosRegistros(!_seleccionarTodos),
              tooltip: 'Seleccionar todos',
            ),
          if (_seleccionados.any((seleccionado) => seleccionado))
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _eliminarSeleccionados,
              tooltip: 'Eliminar seleccionados',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarRegistros,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
          : _registros.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.list_alt, size: 64, color: Colors.grey),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Actualizar', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_seleccionados.any((seleccionado) => seleccionado))
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.blue[50],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_seleccionados.where((s) => s).length} seleccionados',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                            ),
                            ElevatedButton(
                              onPressed: _eliminarSeleccionados,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Eliminar seleccionados', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _registros.length,
                        itemBuilder: (context, index) {
                          final registro = _registros[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: Checkbox(
                                  value: _seleccionados[index],
                                  onChanged: (value) {
                                    setState(() {
                                      _seleccionados[index] = value!;
                                      _seleccionarTodos = _seleccionados.every((s) => s);
                                    });
                                  },
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
                                    Text(
                                      'DNI: ${registro['dni']}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    if (registro['isBlacklisted'] == 1)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red, width: 0.5),
                                        ),
                                        child: const Text(
                                          'LISTA NEGRA',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.info_outline, color: Color(0xFF1565C0)),
                                      onPressed: () => _mostrarDetallesCompletos(index),
                                      tooltip: 'Ver detalles',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _eliminarRegistro(index),
                                      tooltip: 'Eliminar',
                                    ),
                                  ],
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                dense: true,
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

  void _mostrarDialogoImagenesDNI(Map<String, dynamic> registro) {
    int currentPage = 0;
    final PageController controller = PageController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentPage == 0 ? 'Frente del DNI' : 'Reverso del DNI',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                width: 250,
                child: PageView(
                  controller: controller,
                  onPageChanged: (page) {
                    setState(() {
                      currentPage = page;
                    });
                  },
                  children: [
                    Image.file(File(registro['fotoDniFrente']), fit: BoxFit.contain),
                    Image.file(File(registro['fotoDniReverso']), fit: BoxFit.contain),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (currentPage > 0) {
                        controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Anterior', style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (currentPage < 1) {
                        controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Siguiente', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}