import 'package:sitramix/models/common/json_utils.dart';

enum EstadoSancion {
  activa('ACTIVA'),
  cumplida('CUMPLIDA'),
  anulada('ANULADA'),
  desconocido('DESCONOCIDO');

  const EstadoSancion(this.apiValue);

  final String apiValue;

  static EstadoSancion fromApi(Object? value) {
    final text = parseApiString(value)?.toUpperCase();
    return values.firstWhere(
      (estado) => estado.apiValue == text,
      orElse: () => EstadoSancion.desconocido,
    );
  }
}

class Sancion {
  const Sancion({
    this.id,
    required this.identificacionConductor,
    required this.motivo,
    this.nombresConductor,
    this.fechaInicio,
    this.fechaFin,
    this.fechaRegistro,
    this.estado = EstadoSancion.activa,
  });

  final int? id;
  final String identificacionConductor;
  final String motivo;
  final String? nombresConductor;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  final DateTime? fechaRegistro;
  final EstadoSancion estado;

  bool cubre(DateTime fecha) {
    final inicio = fechaInicio;
    final fin = fechaFin;
    if (inicio == null || fin == null) {
      return false;
    }
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final desde = DateTime(inicio.year, inicio.month, inicio.day);
    final hasta = DateTime(fin.year, fin.month, fin.day);
    return !dia.isBefore(desde) && !dia.isAfter(hasta);
  }

  bool get vigenteHoy =>
      estado == EstadoSancion.activa && cubre(DateTime.now());

  factory Sancion.fromJson(Map<String, dynamic> json) => Sancion(
    id: parseApiInt(json['id']),
    identificacionConductor:
        parseApiString(json['identificacionConductor']) ?? '',
    motivo: parseApiString(json['motivo']) ?? '',
    nombresConductor: parseApiString(json['nombresConductor']),
    fechaInicio: parseApiDate(json['fechaInicio']),
    fechaFin: parseApiDate(json['fechaFin']),
    fechaRegistro: parseApiDate(json['fechaRegistro']),
    estado: EstadoSancion.fromApi(json['estado']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'identificacionConductor': identificacionConductor,
    'motivo': motivo,
    if (fechaInicio != null) 'fechaInicio': formatApiDate(fechaInicio!),
    if (fechaFin != null) 'fechaFin': formatApiDate(fechaFin!),
  };

  Map<String, dynamic> toJsonUpdate() => <String, dynamic>{
    'motivo': motivo,
    if (fechaInicio != null) 'fechaInicio': formatApiDate(fechaInicio!),
    if (fechaFin != null) 'fechaFin': formatApiDate(fechaFin!),
    'estado': estado.apiValue,
  };
}
