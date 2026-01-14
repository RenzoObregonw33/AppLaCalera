import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lacalera/models/country_model.dart';
import 'package:lacalera/models/registro_constants.dart';
import 'package:lacalera/screens/barcode_scanner_screen.dart';
import 'package:lacalera/screens/secret_screen.dart';
import 'package:lacalera/screens/ver_registros_screen.dart';
import 'package:lacalera/services/api_services.dart';
import 'package:lacalera/services/database_services.dart';
import 'package:lacalera/services/secret_mode_service.dart';
import 'package:lacalera/widgets/loading_dialog.dart';
import 'package:lacalera/widgets/registro_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _cargarModelosContrato();
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
            content: Text(MSG_DNI_DUPLICADO),
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

  Future<void> _cargarModelosContrato() async {
    setState(() {
      _isLoadingModelos = true;
    });

    try {
      print('🔍 Llamando al API ModelodeContrato con ID: 749');
      final result = await ApiService.ModelodeContrato(749);
      print('📥 Respuesta del API: $result');

      if (result['success'] == true && result['data'] != null) {
        print('✅ API respondió exitosamente');
        final templates = result['data']['templates'] as List<dynamic>?;
        print('📋 Templates recibidos: $templates');

        if (templates != null) {
          setState(() {
            _modelosContrato = templates
                .map(
                  (template) => {
                    'id': template['id'],
                    'description': template['description'],
                  },
                )
                .toList();

            print('💾 Modelos procesados: $_modelosContrato');

            // Seleccionar el primer modelo por defecto si hay opciones
            if (_modelosContrato.isNotEmpty) {
              _selectedModeloContrato = _modelosContrato[0]['description'];
              _selectedModeloContratoId = _modelosContrato[0]['id'];
              print(
                '🎯 Modelo seleccionado por defecto: $_selectedModeloContrato (ID: $_selectedModeloContratoId)',
              );
            }
          });
        } else {
          print('❌ Templates es null');
          _usarValoresPorDefecto();
        }
      } else {
        print('❌ API no fue exitoso o data es null');
        print('📄 Success: ${result['success']}');
        print('📄 Data: ${result['data']}');
        _usarValoresPorDefecto();
      }
    } catch (e) {
      print('💥 Error al cargar modelos: $e');
      _usarValoresPorDefecto();
    } finally {
      setState(() {
        _isLoadingModelos = false;
      });
    }
  }

  void _usarValoresPorDefecto() {
    setState(() {
      _modelosContrato = [
        {'id': 1, 'description': 'Template default'},
      ];
      _selectedModeloContrato = 'Template default';
      _selectedModeloContratoId = 1;
    });
    print('⚠️ Usando valores por defecto');
  }

  final _telefonoCtrl = TextEditingController();
  String? _selectedModeloContrato;
  int? _selectedModeloContratoId;
  List<Map<String, dynamic>> _modelosContrato = [];
  bool _isLoadingModelos = false;
  File? _fotoDniFrente;
  File? _fotoDniReverso;
  final ImagePicker _picker = ImagePicker();
  bool _isCheckingBlacklist = false;
  bool _isBlacklisted = false;

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
      builder: (context) => buildCountryPickerDialog(
        COUNTRIES_LIST,
        (country) {
          setState(() {
            _selectedCountry = country;
          });
        },
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
        const SnackBar(content: Text(MSG_DNI_ESCANEADO)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(MSG_CODIGO_NO_VALIDO)),
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

    final bool isBlacklisted = await DatabaseService.isDniBlacklisted(
      dni,
      organiId,
    );

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
      }

      // Crear nombre único para el archivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_$tipo.jpg';
      final filePath = '${fotosDir.path}/$fileName';

      // Verificar que el archivo fuente existe
      final sourceFile = File(foto.path);
      if (!await sourceFile.exists()) {
        return null;
      }

      // Copiar el archivo
      final file = await sourceFile.copy(filePath);

      return file;
    } catch (e) {
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
          content: Text(MSG_FOTO_FRENTE_CAPTURADA),
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
          content: Text(MSG_FOTO_REVERSO_CAPTURADA),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _guardarRegistro() async {
    // Validar campos del formulario
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(MSG_CAMPOS_OBLIGATORIOS)),
      );
      return;
    }

    // Validar que existan las fotos
    if (_fotoDniFrente == null || _fotoDniReverso == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(MSG_FOTOS_REQUERIDAS),
        ),
      );
      return;
    }

    // 🆕 Mostrar diálogo de carga
    LoadingDialog.mostrarRegistroCandidato(context);

    try {
      // Verificar que los archivos de fotos existan físicamente
      if (!await File(_fotoDniFrente!.path).exists()) {
        LoadingDialog.cerrar(context); // 🆕 Cerrar diálogo antes del error
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
        LoadingDialog.cerrar(context); // 🆕 Cerrar diálogo antes del error
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

      if (_isBlacklisted) {
        LoadingDialog.cerrar(
          context,
        ); // 🆕 Cerrar diálogo antes del diálogo de confirmación
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("ADVERTENCIA"),
            content: const Text(
              MSG_ADVERTENCIA_BLACKLIST,
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
        // 🆕 Reabrir el diálogo de carga si el usuario confirma continuar
        LoadingDialog.mostrarRegistroCandidato(context);
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

      // 🎯 NUEVA LÓGICA: Intentar enviar directamente a la nube primero
      bool enviadoALaNube = false;
      String mensajeResultado = "";

      try {
        // Convertir fotos a base64 para envío a API
        String? fotoFrontBase64;
        String? fotoReverseBase64;

        final bytesFrente = await File(_fotoDniFrente!.path).readAsBytes();
        final bytesReverso = await File(_fotoDniReverso!.path).readAsBytes();

        fotoFrontBase64 = base64Encode(bytesFrente);
        fotoReverseBase64 = base64Encode(bytesReverso);

        // Intentar envío a API
        final apiResponse = await ApiService.sendPersonToApi(
          document: _dniCtrl.text,
          id: organiId,
          templateId: _selectedModeloContratoId ?? 1,
          movil: telefonoCompleto ?? '',
          photoFrontBase64: fotoFrontBase64,
          photoReverseBase64: fotoReverseBase64,
        );

        if (apiResponse['success'] == true) {
          enviadoALaNube = true;
          mensajeResultado = MSG_REGISTRO_EXITOSO;
        } else {
          mensajeResultado =
              "${apiResponse['message'] ?? 'Error desconocido'} - Guardado localmente";
        }
      } catch (e) {
        mensajeResultado = MSG_SIN_CONEXION;
      }

      // 📝 Guardar en base de datos local (siempre)
      final id = await DatabaseService.insertPerson({
        'nombre': _nombreCtrl.text,
        'apellidoPaterno': _apellidoPaternoCtrl.text,
        'dni': _dniCtrl.text,
        'telefono': telefonoCompleto,
        'modeloContrato': _selectedModeloContratoId?.toString() ?? '',
        'fotoDniFrente': _fotoDniFrente!.path,
        'fotoDniReverso': _fotoDniReverso!.path,
        'isBlacklisted': _isBlacklisted ? 1 : 0,
        'organi_id': organiId,
        'enviadaNube': enviadoALaNube
            ? 1
            : 0, // 🎯 Marcar si se envió a la nube
      }, context);

      if (id != 0) {
        // 🆕 Cerrar diálogo de carga antes de mostrar el resultado
        LoadingDialog.cerrar(context);

        // Mostrar mensaje según el resultado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeResultado),
            backgroundColor: enviadoALaNube ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );

        // Limpiar formulario solo si el guardado fue exitoso
        _nombreCtrl.clear();
        _apellidoPaternoCtrl.clear();
        _dniCtrl.clear();
        _telefonoCtrl.clear();
        setState(() {
          _fotoDniFrente = null;
          _fotoDniReverso = null;
          _selectedModeloContrato = null;
          _selectedModeloContratoId = null;
          _selectedCountry = _countries.firstWhere(
            (c) => c.code == 'PE',
          ); // Volver a Perú por defecto
          _isBlacklisted = false;
          _dniDuplicado = false;
        });
      } else {
        // 🆕 Cerrar diálogo de carga antes de mostrar el error
        LoadingDialog.cerrar(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error al guardar el registro - DNI duplicado"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 🆕 Cerrar diálogo de carga en caso de error
      LoadingDialog.cerrar(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al procesar el registro: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
    // Ya no necesitamos el finally con _isLoading
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
        _selectedModeloContrato = null;
        _selectedModeloContratoId = null;
        _selectedCountry = _countries.firstWhere((c) => c.code == 'PE');
        _isBlacklisted = false;
      });
    });
  }

  void _irAPantallaErrores() {
    Navigator.pop(context); // Cierra el Drawer si está abierto
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SecretScreen()),
    );
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
        backgroundColor: PRIMARY_COLOR,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
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
              buildSectionHeader(title: "DNI", icon: Icons.badge_outlined),
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
              buildSectionHeader(
                title: "Información Personal",
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreCtrl,
                decoration: InputDecoration(
                  labelText: LABEL_NOMBRE,
                  prefixIcon: Icon(Icons.person, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(INPUT_FIELD_RADIUS),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? "Campo requerido" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _apellidoPaternoCtrl,
                decoration: InputDecoration(
                  labelText: LABEL_APELLIDO,
                  prefixIcon: Icon(Icons.person, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(INPUT_FIELD_RADIUS),
                  ),
                ),
                // Removida validación - ahora es opcional
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  // Selector de código de país (ahora clickeable)
                  buildCountrySelector(_selectedCountry, _showCountryPicker),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _telefonoCtrl,
                      decoration: InputDecoration(
                        labelText: LABEL_TELEFONO,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(INPUT_FIELD_RADIUS),
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
              buildSectionHeader(
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
                items: _isLoadingModelos
                    ? [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Cargando...'),
                        ),
                      ]
                    : _modelosContrato
                          .map(
                            (modelo) => DropdownMenuItem<String>(
                              value: modelo['description'],
                              child: Text(modelo['description']),
                            ),
                          )
                          .toList(),
                onChanged: _isLoadingModelos
                    ? null
                    : (v) {
                        setState(() {
                          _selectedModeloContrato = v;
                          // Buscar el ID correspondiente a la descripción seleccionada
                          final modeloSeleccionado = _modelosContrato
                              .firstWhere(
                                (modelo) => modelo['description'] == v,
                                orElse: () => {'id': null},
                              );
                          _selectedModeloContratoId = modeloSeleccionado['id'];
                        });
                      },
                validator: (v) =>
                    v == null ? "Selecciona un modelo de contrato" : null,
              ),
              const SizedBox(height: 24),

              // Sección Documento de Identidad
              buildSectionHeader(
                title: "Documento de Identidad",
                icon: Icons.credit_card,
              ),
              const SizedBox(height: 12),

              // Fila con los botones de fotos del DNI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Botón para foto del frente
                  buildFotoButton(
                    "Frente del DNI",
                    _fotoDniFrente,
                    _tomarFotoFrente,
                  ),

                  // Botón para foto del reverso
                  buildFotoButton(
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
                        : PRIMARY_COLOR,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BUTTON_RADIUS),
                    ),
                  ),
                  child: Text(
                    _dniDuplicado ? LABEL_DNI_REGISTRADO : LABEL_REGISTRAR,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
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
    return ListenableBuilder(
      listenable: SecretModeService(),
      builder: (context, child) {
        final secretService = SecretModeService();

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
                leading: const Icon(Icons.sync, color: PRIMARY_COLOR),
                title: const Text('Sincronizar'),
                onTap: _sincronizar,
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: PRIMARY_COLOR),
                title: const Text('Colaboradores'),
                onTap: _verRegistros,
              ),
              // Mostrar opción de errores solo si el modo está activado
              if (secretService.isErrorModeEnabled)
                ListTile(
                  leading: const Icon(Icons.error, color: PRIMARY_COLOR),
                  title: const Text('Modo Debug'),
                  onTap: _irAPantallaErrores,
                ),
            ],
          ),
        );
      },
    );
  }
}
