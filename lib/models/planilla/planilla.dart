import 'package:sitramix/models/common/json_utils.dart';

enum EstadoPlanilla {
  activa('ACTIVA'),
  anulada('ANULADA'),
  desconocido('DESCONOCIDO');

  const EstadoPlanilla(this.apiValue);

  final String apiValue;

  static EstadoPlanilla fromApi(Object? value) {
    final text = parseApiString(value)?.toUpperCase();
    return values.firstWhere(
      (estado) => estado.apiValue == text,
      orElse: () => EstadoPlanilla.desconocido,
    );
  }
}

enum EstadoPago {
  pendiente('PENDIENTE'),
  pagada('PAGADA'),
  desconocido('DESCONOCIDO');

  const EstadoPago(this.apiValue);

  final String apiValue;

  static EstadoPago fromApi(Object? value) {
    final text = parseApiString(value)?.toUpperCase();
    return values.firstWhere(
      (estado) => estado.apiValue == text,
      orElse: () => EstadoPago.desconocido,
    );
  }
}

class ConductorResumen {
  const ConductorResumen({required this.identificacion, required this.nombre});

  final String identificacion;
  final String nombre;

  factory ConductorResumen.fromJson(Map<String, dynamic> json) =>
      ConductorResumen(
        identificacion: parseApiString(json['Identificacion']) ?? '',
        nombre: parseApiString(json['Nombre del conductor']) ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'Identificacion': identificacion,
    'Nombre del conductor': nombre,
  };
}

class Planilla {
  const Planilla({
    this.numero,
    this.fecha,
    this.hora,
    this.placaVehiculo,
    this.tipo,
    this.estado = EstadoPlanilla.activa,
    this.tarifaId,
    this.valorPagado = 0,
    this.estadoPago = EstadoPago.pendiente,
    this.conductor,
  });

  final int? numero;
  final DateTime? fecha;

  final String? hora;
  final String? placaVehiculo;
  final String? tipo;
  final EstadoPlanilla estado;
  final int? tarifaId;
  final double valorPagado;
  final EstadoPago estadoPago;
  final ConductorResumen? conductor;

  bool get estaPagada => estadoPago == EstadoPago.pagada;

  factory Planilla.fromJson(Map<String, dynamic> json) {
    final conductorJson = json['conductor'];
    return Planilla(
      numero: parseApiInt(json['numero']),
      fecha: parseApiDate(json['fecha']),
      hora: parseApiString(json['hora']),
      placaVehiculo: parseApiString(json['placaVehiculo']),
      tipo: parseApiString(json['tipo']),
      estado: EstadoPlanilla.fromApi(json['estado']),
      tarifaId: parseApiInt(json['tarifaId']),
      valorPagado: parseApiDouble(json['valorPagado']) ?? 0,
      estadoPago: EstadoPago.fromApi(json['estadoPago']),
      conductor: conductorJson is Map<String, dynamic>
          ? ConductorResumen.fromJson(conductorJson)
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (fecha != null) 'fecha': formatApiDate(fecha!),
    if (placaVehiculo != null) 'placaVehiculo': placaVehiculo,
    if (tipo != null) 'tipo': tipo,
    'estado': estado.apiValue,
    if (tarifaId != null) 'tarifaId': tarifaId,
  };
}

class PlanillaMasivaRequest {
  const PlanillaMasivaRequest({
    required this.fecha,
    required this.placasVehiculos,
    required this.tipo,
    required this.tarifaId,
  });

  final DateTime fecha;
  final List<String> placasVehiculos;
  final String tipo;
  final int tarifaId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fecha': formatApiDate(fecha),
    'placasVehiculos': placasVehiculos,
    'tipo': tipo,
    'tarifaId': tarifaId,
  };
}

class PlanillaRechazada {
  const PlanillaRechazada({
    required this.placaVehiculo,
    required this.codigo,
    required this.motivo,
  });

  final String placaVehiculo;

  final int codigo;
  final String motivo;

  factory PlanillaRechazada.fromJson(Map<String, dynamic> json) =>
      PlanillaRechazada(
        placaVehiculo: parseApiString(json['placaVehiculo']) ?? '',
        codigo: parseApiInt(json['codigo']) ?? 0,
        motivo: parseApiString(json['motivo']) ?? '',
      );
}

class InformePlanillasMasivas {
  const InformePlanillasMasivas({
    required this.totalSolicitadas,
    required this.totalRegistradas,
    required this.totalRechazadas,
    required this.correctas,
    required this.rechazadas,
  });

  final int totalSolicitadas;
  final int totalRegistradas;
  final int totalRechazadas;
  final List<Planilla> correctas;
  final List<PlanillaRechazada> rechazadas;

  bool get esCoherente =>
      totalSolicitadas == totalRegistradas + totalRechazadas;

  factory InformePlanillasMasivas.fromJson(Map<String, dynamic> json) {
    final correctas = json['correctas'];
    final rechazadas = json['rechazadas'];
    return InformePlanillasMasivas(
      totalSolicitadas: parseApiInt(json['totalSolicitadas']) ?? 0,
      totalRegistradas: parseApiInt(json['totalRegistradas']) ?? 0,
      totalRechazadas: parseApiInt(json['totalRechazadas']) ?? 0,
      correctas: correctas is List
          ? correctas
                .whereType<Map<String, dynamic>>()
                .map(Planilla.fromJson)
                .toList(growable: false)
          : const <Planilla>[],
      rechazadas: rechazadas is List
          ? rechazadas
                .whereType<Map<String, dynamic>>()
                .map(PlanillaRechazada.fromJson)
                .toList(growable: false)
          : const <PlanillaRechazada>[],
    );
  }
}
