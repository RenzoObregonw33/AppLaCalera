import 'package:flutter/material.dart';
import 'package:lacalera/services/api_services.dart';
import 'package:lacalera/services/database_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({Key? key}) : super(key: key);

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  Future<void> _syncFromApi() async {
    print('🔄 Solicitando datos a la API...');
    
    // Obtener el organi_id actual
    final prefs = await SharedPreferences.getInstance();
    final organiId = prefs.getInt('organi_id') ?? 0;
    
    final apiData = await ApiService.fetchBlacklistFromApi(organiId);
    print('📥 Datos recibidos de la API:');
    print(apiData);
    if (apiData.isNotEmpty) {
      final result = await DatabaseService.syncBlacklistFromApi(apiData, organiId);
      print('💾 Resultado de guardado en base local: $result');
      await _loadBlacklist();
      print('📂 Datos en base local tras sincronización:');
      print(_blacklist);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Blacklist sincronizada desde la API.')),
        );
      }
    } else {
      print(
        '⚠️ La API devolvió una lista vacía, no se actualiza la blacklist local.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La API no devolvió datos, la blacklist local se mantiene.',
            ),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _blacklist = [];

  @override
  void initState() {
    super.initState();
    _loadBlacklist();
  }

  Future<void> _loadBlacklist() async {
    print('📋 ===== CARGANDO BLACKLIST EN PANTALLA =====');
    
    // Obtener el organi_id actual
    final prefs = await SharedPreferences.getInstance();
    final organiId = prefs.getInt('organi_id') ?? 0;
    
    print('🏢 Organización seleccionada: $organiId');
    
    final data = await DatabaseService.getBlacklist(organiId);
    
    print('📊 Registros cargados para mostrar en UI: ${data.length}');
    if (data.isNotEmpty) {
      print('📄 Datos que se mostrarán en la pantalla:');
      for (int i = 0; i < data.length; i++) {
        final item = data[i];
        print('   ${i + 1}. DNI: ${item['dni']} | Razón: ${item['reason']}');
      }
    } else {
      print('📝 No hay datos para mostrar en la pantalla');
    }
    print('📋 ==========================================');
    
    setState(() {
      _blacklist = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Visualización Blacklist Local"),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar con API',
            onPressed: _syncFromApi,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _blacklist.isEmpty
            ? const Center(child: Text("No hay datos en la blacklist local."))
            : ListView.builder(
                itemCount: _blacklist.length,
                itemBuilder: (context, index) {
                  final item = _blacklist[index];
                  return ListTile(
                    leading: const Icon(Icons.warning, color: Colors.red),
                    title: Text(item['dni'] ?? ''),
                    subtitle: Text(item['reason'] ?? 'Sin motivo'),
                  );
                },
              ),
      ),
    );
  }
}
