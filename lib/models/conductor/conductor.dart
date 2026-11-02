import 'package:sitramix/models/common/json_utils.dart';

class Conductor {
  const Conductor({
    required this.identificacion,
    required this.nombres,
    required this.activo,
    this.fechaNacimiento,
    this.numeroLicencia,
    this.categoriaLicencia,
    this.vigenciaLicencia,
    this.celular,
    this.correo,
  });

  final String identificacion;
  final String nombres;
  final bool activo;
  final DateTime? fechaNacimiento;
  final String? numeroLicencia;
  final String? categoriaLicencia;
  final DateTime? vigenciaLicencia;
  final String? celular;
  final String? correo;

  bool get licenciaVencida {
    final vigencia = vigenciaLicencia;
    if (vigencia == null) {
      return false;
    }
    return vigencia.isBefore(DateTime.now());
  }

  factory Conductor.fromJson(Map<String, dynamic> json) => Conductor(
    identificacion: parseApiString(json['identificacion']) ?? '',
    nombres: parseApiString(json['nombres']) ?? '',
    activo: parseApiBool(json['activo']) ?? true,
    fechaNacimiento: parseApiDate(json['fechaNacimiento']),
    numeroLicencia: parseApiString(json['numeroLicencia']),
    categoriaLicencia: parseApiString(json['categoriaLicencia']),
    vigenciaLicencia: parseApiDate(json['vigenciaLicencia']),
    celular: parseApiString(json['celular']),
    correo: parseApiString(json['correo']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'identificacion': identificacion,
    'nombres': nombres,
    'activo': activo,
    if (fechaNacimiento != null)
      'fechaNacimiento': formatApiDate(fechaNacimiento!),
    if (numeroLicencia != null) 'numeroLicencia': numeroLicencia,
    if (categoriaLicencia != null) 'categoriaLicencia': categoriaLicencia,
    if (vigenciaLicencia != null)
      'vigenciaLicencia': formatApiDate(vigenciaLicencia!),
    if (celular != null) 'celular': celular,
    if (correo != null) 'correo': correo,
  };

  Map<String, dynamic> toJsonUpdate() => toJson()..remove('identificacion');
}
