import 'package:flutter/material.dart';
import 'package:lacalera/services/api_services.dart';
import 'package:lacalera/services/database_services.dart';

class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({Key? key}) : super(key: key);

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  Future<void> _syncFromApi() async {
    print('🔄 Solicitando datos a la API...');
    final apiData = await ApiService.fetchBlacklistFromApi(749);
    print('📥 Datos recibidos de la API:');
    print(apiData);
    if (apiData.isNotEmpty) {
      final result = await DatabaseService.syncBlacklistFromApi(apiData);
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
    final data = await DatabaseService.getBlacklist();
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
