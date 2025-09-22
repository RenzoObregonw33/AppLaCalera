import 'package:flutter/material.dart';
import 'package:lacalera/services/database_services.dart';

class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  List<Map<String, dynamic>> _blacklist = [];

  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

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

  Future<void> _addBlacklist() async {
    final dni = _dniController.text.trim();
    final reason = _reasonController.text.trim();

    if (dni.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("El DNI debe tener 8 dígitos")),
      );
      return;
    }

    await DatabaseService.addToBlacklist(dni, reason: reason.isNotEmpty ? reason : "Sin motivo");
    _dniController.clear();
    _reasonController.clear();
    _loadBlacklist();
  }

  Future<void> _removeBlacklist(String dni) async {
    await DatabaseService.removeFromBlacklist(dni);
    _loadBlacklist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Blacklist"),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Formulario de entrada
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _dniController,
                  decoration: const InputDecoration(
                    labelText: "DNI",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: "Motivo (opcional)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _addBlacklist,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Agregar a Blacklist", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          const Divider(),

          // Lista de blacklist
          Expanded(
            child: _blacklist.isEmpty
                ? const Center(child: Text("No hay DNIs en la lista negra"))
                : ListView.builder(
                    itemCount: _blacklist.length,
                    itemBuilder: (context, index) {
                      final item = _blacklist[index];
                      return ListTile(
                        leading: const Icon(Icons.block, color: Colors.red),
                        title: Text(item['dni']),
                        subtitle: Text(item['reason'] ?? "Sin motivo"),
                        trailing: Text(
                          item['created_at']?.toString().substring(0, 10) ?? '',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        onLongPress: () async {
                          final confirmar = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Eliminar de Blacklist"),
                              content: Text("¿Desea eliminar el DNI ${item['dni']} de la blacklist?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Cancelar"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Eliminar"),
                                ),
                              ],
                            ),
                          );

                          if (confirmar == true) {
                            _removeBlacklist(item['dni']);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
