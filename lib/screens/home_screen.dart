import 'package:flutter/material.dart';
import 'package:lacalera/models/user_models.dart';
import 'package:lacalera/screens/login_screen.dart';
import 'package:lacalera/screens/registro_screen.dart';
import 'package:lacalera/services/database_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatelessWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  // Método para cerrar sesión
  void _cerrarSesion(BuildContext context) async {
    // Mostrar diálogo de confirmación
    final confirmar = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFF1565C0)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      // Limpiar datos de sesión

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      // Navegar al LoginScreen y eliminar historial
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        automaticallyImplyLeading: false,
        // BOTÓN DE CERRAR SESIÓN A LA IZQUIERDA
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => _cerrarSesion(context),
          tooltip: 'Cerrar sesión',
        ),
        // TÍTULO CENTRADO
        title: const Text(
          'Organización',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Resetear base de datos',
            onPressed: () async {
              // Importa DatabaseService si no está importado
              await DatabaseService.resetDatabase();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Base de datos reseteada')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey[300],
                      child: user.fotoUrl.isNotEmpty && user.fotoUrl != 'null'
                          ? ClipOval(
                              child: Image.network(
                                user.fotoUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.white,
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                            : null,
                                      );
                                    },
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.white,
                            ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF72C8C0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF72C8C0),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'Online',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${user.persoNombre} ${user.persoApPaterno} ${user.persoApMaterno}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        user.rolNombre.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Mis organizaciones:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: user.organizaciones.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 15),
                itemBuilder: (context, index) {
                  final org = user.organizaciones[index];

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      // Guarda el organi_id seleccionado en SharedPreferences
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('organi_id', org.organiId);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegistroScreen(),
                        ),
                      );
                    },
                    child: Card(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.all(16),
                        constraints: const BoxConstraints(minHeight: 140),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.domain,
                                  color: Color(0xFF1565C0),
                                  size: 28,
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Text(
                                    org.organiRazonSocial,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'RUC: ${org.organiRuc}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tipo: ${org.organiTipo}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cantidad de empleados: ${org.cantidadEmpleadosLumina}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                              ),
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
      ),
    );
  }
}
