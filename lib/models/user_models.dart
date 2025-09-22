// user_model.dart
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
      id: json['id'],
      activo: json['activo'],
      foto: json['foto'],
      persoNombre: json['perso_nombre'],
      persoApPaterno: json['perso_apPaterno'],
      persoApMaterno: json['perso_apMaterno'],
      email: json['email'],
      fotoUrl: json['foto_url'],
      rolId: json['rol_id'],
      rolNombre: json['rol_nombre'],
      organizaciones: (json['organizaciones'] as List)
          .map((org) => Organizacion.fromJson(org))
          .toList(),
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
      organiId: json['organi_id'],
      organiRuc: json['organi_ruc'],
      organiRazonSocial: json['organi_razonSocial'],
      organiTipo: json['organi_tipo'],
      cantidadEmpleadosLumina: json['cantidad_empleados_lumina'],
    );
  }
}