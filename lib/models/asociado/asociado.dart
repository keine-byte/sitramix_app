import 'package:sitramix/models/common/json_utils.dart';

class Asociado {
  const Asociado({
    required this.identificacion,
    required this.nombres,
    required this.activo,
    this.celular,
    this.correo,
    this.fechaNacimiento,
    this.fechaIngreso,
    this.fechaRegistro,
    this.ultimaActualizacion,
  });

  final String identificacion;
  final String nombres;
  final bool activo;
  final String? celular;
  final String? correo;
  final DateTime? fechaNacimiento;
  final DateTime? fechaIngreso;

  final DateTime? fechaRegistro;
  final DateTime? ultimaActualizacion;

  factory Asociado.fromJson(Map<String, dynamic> json) => Asociado(
    identificacion: parseApiString(json['identificacion']) ?? '',
    nombres: parseApiString(json['nombres']) ?? '',
    activo: parseApiBool(json['activo']) ?? true,
    celular: parseApiString(json['celular']),
    correo: parseApiString(json['correo']),
    fechaNacimiento: parseApiDate(json['fechaNacimiento']),
    fechaIngreso: parseApiDate(json['fechaIngreso']),
    fechaRegistro: parseApiDate(json['fechaRegistro']),
    ultimaActualizacion: parseApiDate(json['ultimaActualizacion']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'identificacion': identificacion,
    'nombres': nombres,
    'activo': activo,
    if (celular != null) 'celular': celular,
    if (correo != null) 'correo': correo,
    if (fechaNacimiento != null)
      'fechaNacimiento': formatApiDate(fechaNacimiento!),
  };

  Map<String, dynamic> toJsonUpdate() => <String, dynamic>{
    'nombres': nombres,
    'activo': activo,
    if (celular != null) 'celular': celular,
    if (correo != null) 'correo': correo,
    if (fechaNacimiento != null)
      'fechaNacimiento': formatApiDate(fechaNacimiento!),
    if (fechaIngreso != null) 'fechaIngreso': formatApiDate(fechaIngreso!),
  };
}

class CredencialTemporal {
  const CredencialTemporal({
    required this.username,
    required this.passwordTemporal,
  });

  final String username;
  final String passwordTemporal;

  factory CredencialTemporal.fromJson(Map<String, dynamic> json) =>
      CredencialTemporal(
        username: parseApiString(json['username']) ?? '',
        passwordTemporal: parseApiString(json['passwordTemporal']) ?? '',
      );
}
