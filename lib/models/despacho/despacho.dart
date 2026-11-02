import 'package:sitramix/models/common/json_utils.dart';

enum EstadoDespacho {
  registrado('REGISTRADO'),
  cancelado('CANCELADO'),
  desconocido('DESCONOCIDO');

  const EstadoDespacho(this.apiValue);

  final String apiValue;

  static EstadoDespacho fromApi(Object? value) {
    final text = parseApiString(value)?.toUpperCase();
    return values.firstWhere(
      (estado) => estado.apiValue == text,
      orElse: () => EstadoDespacho.desconocido,
    );
  }
}

class Despacho {
  const Despacho({
    this.id,
    required this.ruta,
    required this.placaVehiculo,
    required this.numeroPasajeros,
    this.fecha,
    this.hora,
    this.estado = EstadoDespacho.registrado,
    this.fechaRegistro,
    this.registradoPor,
    this.fechaCancelacion,
    this.canceladoPor,
    this.motivoCancelacion,
  });

  final int? id;
  final String ruta;
  final String placaVehiculo;
  final int numeroPasajeros;
  final DateTime? fecha;
  final String? hora;
  final EstadoDespacho estado;
  final DateTime? fechaRegistro;
  final String? registradoPor;
  final DateTime? fechaCancelacion;
  final String? canceladoPor;
  final String? motivoCancelacion;

  bool get estaCancelado => estado == EstadoDespacho.cancelado;

  factory Despacho.fromJson(Map<String, dynamic> json) => Despacho(
    id: parseApiInt(json['id']),
    ruta: parseApiString(json['ruta']) ?? '',
    placaVehiculo: parseApiString(json['placaVehiculo']) ?? '',
    numeroPasajeros: parseApiInt(json['numeroPasajeros']) ?? 0,
    fecha: parseApiDate(json['fecha']),
    hora: parseApiString(json['hora']),
    estado: EstadoDespacho.fromApi(json['estado']),
    fechaRegistro: parseApiDate(json['fechaRegistro']),
    registradoPor: parseApiString(json['registradoPor']),
    fechaCancelacion: parseApiDate(json['fechaCancelacion']),
    canceladoPor: parseApiString(json['canceladoPor']),
    motivoCancelacion: parseApiString(json['motivoCancelacion']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'ruta': ruta,
    'placaVehiculo': placaVehiculo,
    if (hora != null) 'hora': hora,
    if (fecha != null) 'fecha': formatApiDate(fecha!),
    'numeroPasajeros': numeroPasajeros,
  };
}
