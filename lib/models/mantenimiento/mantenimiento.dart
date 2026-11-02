import 'package:sitramix/models/common/json_utils.dart';

enum EstadoMantenimiento {
  enMantenimiento('EN_MANTENIMIENTO'),
  finalizado('FINALIZADO'),
  desconocido('DESCONOCIDO');

  const EstadoMantenimiento(this.apiValue);

  final String apiValue;

  static EstadoMantenimiento fromApi(Object? value) {
    final text = parseApiString(value)?.toUpperCase();
    return values.firstWhere(
      (estado) => estado.apiValue == text,
      orElse: () => EstadoMantenimiento.desconocido,
    );
  }
}

class Mantenimiento {
  const Mantenimiento({
    this.id,
    required this.placaVehiculo,
    this.fechaIngreso,
    this.fechaSalida,
    this.motivo,
    this.estadoVehiculoIngreso,
    this.observaciones,
    this.estado = EstadoMantenimiento.enMantenimiento,
  });

  final int? id;
  final String placaVehiculo;
  final DateTime? fechaIngreso;
  final DateTime? fechaSalida;
  final String? motivo;

  final String? estadoVehiculoIngreso;

  final String? observaciones;
  final EstadoMantenimiento estado;

  bool get estaAbierto => estado == EstadoMantenimiento.enMantenimiento;

  factory Mantenimiento.fromJson(Map<String, dynamic> json) => Mantenimiento(
    id: parseApiInt(json['id']),
    placaVehiculo: parseApiString(json['placaVehiculo']) ?? '',
    fechaIngreso: parseApiDate(json['fechaIngreso']),
    fechaSalida: parseApiDate(json['fechaSalida']),
    motivo: parseApiString(json['motivo']),
    estadoVehiculoIngreso: parseApiString(json['estadoVehiculoIngreso']),
    observaciones: parseApiString(json['observaciones']),
    estado: EstadoMantenimiento.fromApi(json['estado']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'placaVehiculo': placaVehiculo,
    if (fechaIngreso != null) 'fechaIngreso': formatApiDateTime(fechaIngreso!),
    if (motivo != null) 'motivo': motivo,
    if (estadoVehiculoIngreso != null)
      'estadoVehiculoIngreso': estadoVehiculoIngreso,
    if (observaciones != null) 'observaciones': observaciones,
  };
}

Map<String, dynamic> mantenimientoSalidaBody({
  required DateTime fechaSalida,
  required String observaciones,
}) => <String, dynamic>{
  'fechaSalida': formatApiDateTime(fechaSalida),
  'observaciones': observaciones,
};
