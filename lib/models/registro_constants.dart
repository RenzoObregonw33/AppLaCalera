import 'package:flutter/material.dart';
import 'country_model.dart';

// Lista de países
final List<Country> COUNTRIES_LIST = [
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

// Colores
const Color PRIMARY_COLOR = Color(0xFF1565C0);
const Color SUCCESS_COLOR = Colors.green;
const Color WARNING_COLOR = Colors.orange;
const Color ERROR_COLOR = Colors.red;
const Color BACKGROUND_COLOR = Colors.white;

// Tamaños
const double SPACING_SMALL = 8;
const double SPACING_MEDIUM = 12;
const double SPACING_LARGE = 16;
const double SPACING_XLARGE = 24;
const double SPACING_XXLARGE = 30;

const double BUTTON_RADIUS = 12;
const double INPUT_FIELD_RADIUS = 12;
const double ICON_SIZE = 24;
const double LARGE_ICON_SIZE = 40;
const double PHOTO_BUTTON_SIZE = 120;

// Textos
const String LABEL_DNI = "Ingrese DNI (8 dígitos)";
const String LABEL_NOMBRE = "Nombre";
const String LABEL_APELLIDO = "Apellido Paterno (opcional)";
const String LABEL_TELEFONO = "Teléfono (opcional)";
const String LABEL_MODELO_CONTRATO = "Modelo de Contrato";
const String LABEL_REGISTRAR = "Registrar Candidato";
const String LABEL_DNI_REGISTRADO = "DNI ya registrado";

const String MSG_DNI_DUPLICADO =
    'DNI duplicado. No puedes registrar este candidato.';
const String MSG_DNI_ESCANEADO = "DNI escaneado correctamente";
const String MSG_CODIGO_NO_VALIDO = "Código de barras no válido";
const String MSG_FOTOS_REQUERIDAS =
    "Debes tomar las fotos del DNI (frente y reverso)";
const String MSG_CAMPOS_OBLIGATORIOS = "Completa todos los campos obligatorios";
const String MSG_ADVERTENCIA_BLACKLIST =
    "Este DNI está en la lista negra. ¿Está seguro de que desea guardar el registro?";
const String MSG_REGISTRO_EXITOSO = "Registro enviado exitosamente";
const String MSG_SIN_CONEXION = "Sin conexión - Guardado localmente";
const String MSG_SINCRONIZADO = 'Se ha sincronizado correctamente';
const String MSG_FOTO_FRENTE_CAPTURADA =
    "Foto del frente capturada correctamente";
const String MSG_FOTO_REVERSO_CAPTURADA =
    "Foto del reverso capturada correctamente";
