import 'package:sitramix/models/common/json_utils.dart';

enum EstadoAfiliacion {
  activa('ACTIVA'),
  finalizada('FINALIZADA'),
  desconocido('DESCONOCIDO');

  const EstadoAfiliacion(this.apiValue);

  final String apiValue;

  static EstadoAfiliacion fromApi(Object? value) {
    final text = parseApiString(value)?.toUpperCase();
    return values.firstWhere(
      (estado) => estado.apiValue == text,
      orElse: () => EstadoAfiliacion.desconocido,
    );
  }
}

class Afiliacion {
  const Afiliacion({
    this.id,
    required this.identificacionAsociado,
    required this.placaVehiculo,
    required this.fechaAfiliacion,
    this.fechaFinAfiliacion,
    this.estado = EstadoAfiliacion.activa,
    this.fechaRegistro,
    this.ultimaActualizacion,
  });

  final int? id;
  final String identificacionAsociado;
  final String placaVehiculo;
  final DateTime? fechaAfiliacion;
  final DateTime? fechaFinAfiliacion;
  final EstadoAfiliacion estado;
  final DateTime? fechaRegistro;
  final DateTime? ultimaActualizacion;

  bool get estaActiva => estado == EstadoAfiliacion.activa;

  factory Afiliacion.fromJson(Map<String, dynamic> json) => Afiliacion(
    id: parseApiInt(json['id']),
    identificacionAsociado:
        parseApiString(json['identificacionAsociado']) ?? '',
    placaVehiculo: parseApiString(json['placaVehiculo']) ?? '',
    fechaAfiliacion: parseApiDate(json['fechaAfiliacion']),
    fechaFinAfiliacion: parseApiDate(json['fechaFinAfiliacion']),
    estado: EstadoAfiliacion.fromApi(json['estado']),
    fechaRegistro: parseApiDate(json['fechaRegistro']),
    ultimaActualizacion: parseApiDate(json['ultimaActualizacion']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'identificacionAsociado': identificacionAsociado,
    'placaVehiculo': placaVehiculo,
    if (fechaAfiliacion != null)
      'fechaAfiliacion': formatApiDate(fechaAfiliacion!),
    'fechaFinAfiliacion': fechaFinAfiliacion == null
        ? null
        : formatApiDate(fechaFinAfiliacion!),
    'estado': estado.apiValue,
  };
}
