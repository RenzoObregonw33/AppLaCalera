import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lacalera/screens/barcode_scanner_screen.dart';
import 'package:lacalera/screens/ver_registros_screen.dart';
import 'package:lacalera/services/api_services.dart';
import 'package:lacalera/services/database_services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:lacalera/screens/blacklist_screen.dart';

class Country {
  final String name;
  final String code;
  final String dialCode;
  final String flag;

  Country({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });
}

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  bool _dniDuplicado = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoPaternoCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dniCtrl.addListener(_verificarDniDuplicado);
  }

  String? _ultimoDniDuplicado;
  Future<void> _verificarDniDuplicado() async {
    final dni = _dniCtrl.text.trim();
    if (dni.length == 8) {
      final prefs = await SharedPreferences.getInstance();
      final organiId = prefs.getInt('organi_id') ?? 0;
      final existe = await DatabaseService.dniExiste(dni, organiId: organiId);
      if (existe && (_ultimoDniDuplicado != dni)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('DNI duplicado. No puedes registrar este candidato.'),
            backgroundColor: Colors.black,
            duration: Duration(seconds: 2),
          ),
        );
        _ultimoDniDuplicado = dni;
      } else if (!existe) {
        _ultimoDniDuplicado = null;
      }
      setState(() {
        _dniDuplicado = existe;
      });
    } else {
      setState(() {
        _dniDuplicado = false;
      });
      _ultimoDniDuplicado = null;
    }
  }

  final _telefonoCtrl = TextEditingController();
  String? _selectedModeloContrato = 'Colaborador';
  final List<String> _modeloContrato = ['Colaborador'];
  File? _fotoDniFrente;
  File? _fotoDniReverso;
  final ImagePicker _picker = ImagePicker();
  bool _isCheckingBlacklist = false;
  bool _isBlacklisted = false;

  // Lista de países
  final List<Country> _countries = [
    Country(name: 'Perú', code: 'PE', dialCode: '+51', flag: '🇵🇪'),
    Country(name: 'Argentina', code: 'AR', dialCode: '+54', flag: '🇦🇷'),
    Country(name: 'Bolivia', code: 'BO', dialCode: '+591', flag: '🇧🇴'),
    Country(name: 'Chile', code: 'CL', dialCode: '+56', flag: '🇨🇱'),
    Country(name: 'Colombia', code: 'CO', dialCode: '+57', flag: '🇨🇴'),
    Country(name: 'Ecuador', code: 'EC', dialCode: '+593', flag: '🇪🇨'),
    Country(name: 'México', code: 'MX', dialCode: '+52', flag: '🇲🇽'),
    Country(name: 'España', code: 'ES', dialCode: '+34', flag: '🇪🇸'),
    Country(name: 'Estados Unidos', code: 'US', dialCode: '+1', flag: '🇺🇸'),
    Country(name: 'Brasil', code: 'BR', dialCode: '+55', flag: '🇧🇷'),
    Country(name: 'Venezuela', code: 'VE', dialCode: '+58', flag: '🇻🇪'),
  ];

  // País seleccionado (Perú por defecto)
  Country _selectedCountry = Country(
    name: 'Perú',
    code: 'PE',
    dialCode: '+51',
    flag: '🇵🇪',
  );

  // Función para mostrar el selector de países
  void _showCountryPicker() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Seleccionar País',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                width: 300,
                child: ListView.builder(
                  itemCount: _countries.length,
                  itemBuilder: (context, index) {
                    final country = _countries[index];
                    return ListTile(
                      leading: Text(
                        country.flag,
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(country.name),
                      trailing: Text(
                        country.dialCode,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCountry = country;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Función para escanear el código de barras
  Future<void> _escanearCodigoBarras() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          onBarcodeScanned: (codigo) {
            _procesarCodigoDNI(codigo);
          },
        ),
      ),
    );
  }

  // Función para procesar el código de barras del DNI
  void _procesarCodigoDNI(String codigo) {
    final soloDigitos = codigo.replaceAll(RegExp(r'[^0-9]'), '');

    if (soloDigitos.length >= 8) {
      setState(() {
        _dniCtrl.text = soloDigitos.substring(0, 8);
      });

      // Validar automáticamente después de escanear
      _validarBlacklist(_dniCtrl.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("DNI escaneado correctamente")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Código de barras no válido")),
      );
    }
  }

  // Función para validar contra la blacklist local
  Future<void> _validarBlacklist(String dni) async {
    if (dni.isEmpty || dni.length != 8) return;

    setState(() {
      _isCheckingBlacklist = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    // Obtener el organi_id actual
    final prefs = await SharedPreferences.getInstance();
    final organiId = prefs.getInt('organi_id') ?? 0;

    print('🔍 ===== VALIDANDO DNI CONTRA BLACKLIST =====');
    print('📋 DNI ingresado: $dni');
    print('🏢 Organización actual: $organiId');

    final bool isBlacklisted = await DatabaseService.isDniBlacklisted(
      dni,
      organiId,
    );

    print(
      '⚖️ Resultado validación: ${isBlacklisted ? 'BLOQUEADO ❌' : 'PERMITIDO ✅'}',
    );

    if (isBlacklisted) {
      print('🚫 DNI $dni está en la blacklist de la organización $organiId');
      print('🔴 Se mostrará indicador rojo al usuario');
    } else {
      print('✅ DNI $dni NO está en la blacklist de la organización $organiId');
      print('🟢 Usuario puede continuar con el registro');
    }

    print('🔍 ========================================');

    setState(() {
      _isBlacklisted = isBlacklisted;
      _isCheckingBlacklist = false;
    });
  }

  Future<File?> _tomarFoto(String tipo) async {
    try {
      final XFile? foto = await _picker.pickImage(source: ImageSource.camera);
      if (foto == null) return null;

      // Obtener directorio de documentos de la app
      final directory = await getApplicationDocumentsDirectory();

      // Crear subdirectorio para fotos si no existe
      final fotosDir = Directory('${directory.path}/fotos');
      if (!await fotosDir.exists()) {
        await fotosDir.create(recursive: true);
        print("📁 Directorio de fotos creado: ${fotosDir.path}");
      }

      // Crear nombre único para el archivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_$tipo.jpg';
      final filePath = '${fotosDir.path}/$fileName';

      print("📸 Copiando foto desde: ${foto.path}");
      print("📁 Hacia: $filePath");

      // Verificar que el archivo fuente existe
      final sourceFile = File(foto.path);
      if (!await sourceFile.exists()) {
        print("❌ Archivo fuente no existe: ${foto.path}");
        return null;
      }

      // Copiar el archivo
      final file = await sourceFile.copy(filePath);
      print("✅ Foto guardada exitosamente: $filePath");

      return file;
    } catch (e) {
      print("❌ Error al tomar foto: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al guardar la foto: $e"),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  // Función para tomar foto del frente del DNI
  Future<void> _tomarFotoFrente() async {
    final fotoFrente = await _tomarFoto("dni_frente");
    if (fotoFrente != null) {
      setState(() {
        _fotoDniFrente = fotoFrente;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Foto del frente capturada correctamente"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // Función para tomar foto del reverso del DNI
  Future<void> _tomarFotoReverso() async {
    final fotoReverso = await _tomarFoto("dni_reverso");
    if (fotoReverso != null) {
      setState(() {
        _fotoDniReverso = fotoReverso;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Foto del reverso capturada correctamente"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _guardarRegistro() async {
    print("👉 Entró a _guardarRegistro()");

    // Validar campos del formulario
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos obligatorios")),
      );
      return;
    }

    // Validar que existan las fotos
    if (_fotoDniFrente == null || _fotoDniReverso == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes tomar las fotos del DNI (frente y reverso)"),
        ),
      );
      return;
    }

    // Verificar que los archivos de fotos existan físicamente
    if (!await File(_fotoDniFrente!.path).exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Error: La foto del frente del DNI no se guardó correctamente. Inténtelo de nuevo.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _fotoDniFrente =
            null; // Resetear para que el usuario tome la foto de nuevo
      });
      return;
    }

    if (!await File(_fotoDniReverso!.path).exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Error: La foto del reverso del DNI no se guardó correctamente. Inténtelo de nuevo.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _fotoDniReverso =
            null; // Resetear para que el usuario tome la foto de nuevo
      });
      return;
    }

    print("✅ Pasó validación, guardando en DB...");
    print("📸 Foto frente existe: ${_fotoDniFrente!.path}");
    print("📸 Foto reverso existe: ${_fotoDniReverso!.path}");

    if (_isBlacklisted) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("ADVERTENCIA"),
          content: const Text(
            "Este DNI está en la lista negra. ¿Está seguro de que desea guardar el registro?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Continuar"),
            ),
          ],
        ),
      );

      if (confirmar != true) {
        return;
      }
    }

    // Preparar el teléfono con código de país
    String? telefonoCompleto;
    if (_telefonoCtrl.text.isNotEmpty) {
      telefonoCompleto = '${_selectedCountry.dialCode} ${_telefonoCtrl.text}';
    } else {
      telefonoCompleto = null;
    }

    final prefs = await SharedPreferences.getInstance();
    final organiId = prefs.getInt('organi_id') ?? 0;

    print('💾 ===== GUARDANDO REGISTRO =====');
    print('📋 DNI: ${_dniCtrl.text}');
    print('👤 Nombre: ${_nombreCtrl.text} ${_apellidoPaternoCtrl.text}');
    print('🏢 Organi_ID desde SharedPreferences: $organiId');
    print('💾 ===============================');

    try {
      final id = await DatabaseService.insertPerson({
        'nombre': _nombreCtrl.text,
        'apellidoPaterno': _apellidoPaternoCtrl.text,
        'dni': _dniCtrl.text,
        'telefono': telefonoCompleto,
        'modeloContrato': _selectedModeloContrato,
        'fotoDniFrente': _fotoDniFrente!.path,
        'fotoDniReverso': _fotoDniReverso!.path,
        'isBlacklisted': _isBlacklisted ? 1 : 0,
        'organi_id': organiId,
      }, context);

      if (id != 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Registro guardado ✅")));

        // Limpiar formulario solo si el guardado fue exitoso
        _nombreCtrl.clear();
        _apellidoPaternoCtrl.clear();
        _dniCtrl.clear();
        _telefonoCtrl.clear();
        setState(() {
          _fotoDniFrente = null;
          _fotoDniReverso = null;
          _selectedModeloContrato = 'Colaborador';
          _selectedCountry = _countries.firstWhere(
            (c) => c.code == 'PE',
          ); // Volver a Perú por defecto
          _isBlacklisted = false;
          _dniDuplicado = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error al guardar el registro"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("❌ Error al guardar registro: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al guardar el registro: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _verRegistros() {
    // Cerrar el drawer antes de navegar
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VerRegistrosScreen()),
    ).then((_) {
      // cuando regrese de VerRegistros, vuelve a limpiar y refrescar
      setState(() {
        _nombreCtrl.clear();
        _apellidoPaternoCtrl.clear();
        _dniCtrl.clear();
        _telefonoCtrl.clear();
        _fotoDniFrente = null;
        _fotoDniReverso = null;
        _selectedModeloContrato = 'Colaborador';
        _selectedCountry = _countries.firstWhere((c) => c.code == 'PE');
        _isBlacklisted = false;
      });
    });
  }

  // Función para sincronizar la blacklist local manualmente
  Future<void> _sincronizar() async {
    Navigator.pop(context); // Cierra el Drawer si está abierto

    // Obtén el organi_id desde SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final organiId = prefs.getInt('organi_id') ?? 0;

    // Muestra un indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Llama a la API para obtener la blacklist
    final response = await ApiService.getBlacklist(organiId);

    // Cierra el indicador de carga
    Navigator.of(context, rootNavigator: true).pop();

    if (response['success'] == true && response['blacklisted'] != null) {
      // Obtener organiId actual
      final prefs = await SharedPreferences.getInstance();
      final organiId = prefs.getInt('organi_id') ?? 0;
      // Actualiza la blacklist local
      await DatabaseService.updateBlacklist(
        response['blacklisted'],
        organiId: organiId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se ha sincronizado correctamente'),
          backgroundColor: Colors.black,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message'] ?? 'No se pudo actualizar la lista negra',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Registro de Candidatos"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          /*IconButton(
            icon: Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _resetDatabase,
            tooltip: 'Borrar base de datos (solo desarrollo)',
          ),*/
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState!.openDrawer(),
            tooltip: 'Abrir menú',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección DNI
              _buildSectionHeader(title: "DNI", icon: Icons.badge_outlined),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dniCtrl,
                      decoration: InputDecoration(
                        labelText: "Ingrese DNI (8 dígitos)",
                        prefixIcon: Icon(
                          Icons.numbers,
                          color: Colors.grey.shade400,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: _isCheckingBlacklist
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : _isBlacklisted
                            ? const Icon(Icons.warning, color: Colors.red)
                            : _dniCtrl.text.length == 8
                            ? const Icon(Icons.verified, color: Colors.green)
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return "Campo requerido";
                        } else if (v.length != 8) {
                          return "El DNI debe tener 8 dígitos";
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (value.length == 8) {
                          _validarBlacklist(value);
                        } else {
                          setState(() {
                            _isBlacklisted = false;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Botón para escanear código de barras con imagen personalizada
                  IconButton(
                    icon: Image.asset(
                      'assets/codigoBarras.png',
                      width: 26,
                      height: 26,
                    ),
                    onPressed: _escanearCodigoBarras,
                    tooltip: 'Escanear código de barras del DNI',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isBlacklisted)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: const Text(
                    "El DNI ingresado no está habilitado para continuar con el registro.",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Sección Información Personal
              _buildSectionHeader(
                title: "Información Personal",
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreCtrl,
                decoration: InputDecoration(
                  labelText: "Nombre",
                  prefixIcon: Icon(Icons.person, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? "Campo requerido" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _apellidoPaternoCtrl,
                decoration: InputDecoration(
                  labelText: "Apellido Paterno",
                  prefixIcon: Icon(Icons.person, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? "Campo requerido" : null,
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  // Selector de código de país (ahora clickeable)
                  GestureDetector(
                    onTap: _showCountryPicker,
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _selectedCountry.flag,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _selectedCountry.dialCode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _telefonoCtrl,
                      decoration: InputDecoration(
                        labelText: "Teléfono (opcional)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(
                          15,
                        ), // Máximo 15 dígitos
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sección Modelo de Contrato
              _buildSectionHeader(
                title: "Modelo de Contrato",
                icon: Icons.work_outline,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedModeloContrato,
                decoration: InputDecoration(
                  labelText: "Modelo de Contrato",
                  prefixIcon: Icon(Icons.work, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _modeloContrato
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedModeloContrato = v),
                validator: (v) =>
                    v == null ? "Selecciona un modelo de contrato" : null,
              ),
              const SizedBox(height: 24),

              // Sección Documento de Identidad
              _buildSectionHeader(
                title: "Documento de Identidad",
                icon: Icons.credit_card,
              ),
              const SizedBox(height: 12),

              // Fila con los botones de fotos del DNI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Botón para foto del frente
                  _buildFotoButton(
                    "Frente del DNI",
                    _fotoDniFrente,
                    _tomarFotoFrente,
                  ),

                  // Botón para foto del reverso
                  _buildFotoButton(
                    "Reverso del DNI",
                    _fotoDniReverso,
                    _tomarFotoReverso,
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Botón Guardar
              Center(
                child: ElevatedButton(
                  onPressed: (_isBlacklisted || _dniDuplicado)
                      ? null
                      : _guardarRegistro,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isBlacklisted || _dniDuplicado)
                        ? Colors.grey
                        : const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dniDuplicado
                            ? "DNI ya registrado"
                            : "Registrar Candidato",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para construir el menú lateral (Drawer)
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 130,
            child: DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1565C0)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Opciones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(1, 2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sync, color: Color(0xFF1565C0)),
            title: const Text('Sincronizar'),
            onTap: _sincronizar,
          ),
          ListTile(
            leading: const Icon(Icons.list_alt, color: Color(0xFF1565C0)),
            title: const Text('Colaboradores'),
            onTap: _verRegistros,
          ),
        ],
      ),
    );
  }

  // Widget para construir encabezados de sección
  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1565C0), size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
      ],
    );
  }

  // Widget para construir botones de fotos del DNI
  Widget _buildFotoButton(String label, File? image, VoidCallback onTap) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1565C0), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(image, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        color: const Color(0xFF1565C0),
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tomar foto",
                        style: TextStyle(
                          color: const Color(0xFF1565C0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
