// user_model.dart
int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text == 'null' ? fallback : text;
}

List<Organizacion> _asOrganizations(dynamic value) {
  if (value is! List) return const [];

  return value
      .whereType<Map>()
      .map(
        (org) => Organizacion.fromJson(
          Map<String, dynamic>.from(org),
        ),
      )
      .toList();
}

class User {
  final int id;
  final int activo;
  final String? foto;
  final String persoNombre;
  final String persoApPaterno;
  final String persoApMaterno;
  final String email;
  final String fotoUrl;
  final int rolId;
  final String rolNombre;
  final List<Organizacion> organizaciones;

  User({
    required this.id,
    required this.activo,
    this.foto,
    required this.persoNombre,
    required this.persoApPaterno,
    required this.persoApMaterno,
    required this.email,
    required this.fotoUrl,
    required this.rolId,
    required this.rolNombre,
    required this.organizaciones,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _asInt(json['id']),
      activo: _asInt(json['activo']),
      foto: _asString(json['foto'], fallback: ''),
      persoNombre: _asString(json['perso_nombre']),
      persoApPaterno: _asString(json['perso_apPaterno']),
      persoApMaterno: _asString(json['perso_apMaterno']),
      email: _asString(json['email']),
      fotoUrl: _asString(json['foto_url']),
      rolId: _asInt(json['rol_id']),
      rolNombre: _asString(json['rol_nombre']),
      organizaciones: _asOrganizations(json['organizaciones']),
    );
  }
}

class Organizacion {
  final int organiId;
  final String organiRuc;
  final String organiRazonSocial;
  final String organiTipo;
  final int cantidadEmpleadosLumina;

  Organizacion({
    required this.organiId,
    required this.organiRuc,
    required this.organiRazonSocial,
    required this.organiTipo,
    required this.cantidadEmpleadosLumina,
  });

  factory Organizacion.fromJson(Map<String, dynamic> json) {
    return Organizacion(
      organiId: _asInt(json['organi_id']),
      organiRuc: _asString(json['organi_ruc']),
      organiRazonSocial: _asString(json['organi_razonSocial']),
      organiTipo: _asString(json['organi_tipo']),
      cantidadEmpleadosLumina: _asInt(json['cantidad_empleados_lumina']),
    );
  }
}