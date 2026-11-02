import 'package:sitramix/models/common/json_utils.dart';

class TarifaResumen {
  const TarifaResumen({required this.id, required this.total});

  final int id;
  final double total;

  factory TarifaResumen.fromJson(Map<String, dynamic> json) => TarifaResumen(
    id: parseApiInt(json['id']) ?? 0,
    total: parseApiDouble(json['total']) ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'total': total};
}

class Vehiculo {
  const Vehiculo({
    required this.placa,
    required this.tipo,
    required this.marca,
    required this.modelo,
    required this.capacidadPasajeros,
    required this.tarjetaPropiedad,
    required this.activo,
    this.tarifaId,
    this.tarifa,
    this.vigenciaSoat,
    this.vigenciaTrm,
    this.fechaIngreso,
    this.identificacionConductor,
  });

  final String placa;
  final String tipo;
  final String marca;

  final String modelo;
  final int capacidadPasajeros;
  final String tarjetaPropiedad;
  final bool activo;
  final int? tarifaId;
  final TarifaResumen? tarifa;
  final DateTime? vigenciaSoat;
  final DateTime? vigenciaTrm;
  final DateTime? fechaIngreso;

  final String? identificacionConductor;

  bool get soatVencido {
    final vigencia = vigenciaSoat;
    return vigencia != null && vigencia.isBefore(DateTime.now());
  }

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    final tarifaJson = json['tarifa'];
    return Vehiculo(
      placa: parseApiString(json['placa']) ?? '',
      tipo: parseApiString(json['tipo']) ?? '',
      marca: parseApiString(json['marca']) ?? '',
      modelo: parseApiString(json['modelo']) ?? '',
      capacidadPasajeros: parseApiInt(json['capacidadPasajeros']) ?? 0,
      tarjetaPropiedad: parseApiString(json['tarjetaPropiedad']) ?? '',
      activo: parseApiBool(json['activo']) ?? true,
      tarifaId: parseApiInt(json['tarifaId']),
      tarifa: tarifaJson is Map<String, dynamic>
          ? TarifaResumen.fromJson(tarifaJson)
          : null,
      vigenciaSoat: parseApiDate(json['vigenciaSoat']),
      vigenciaTrm: parseApiDate(json['vigenciaTrm']),
      fechaIngreso: parseApiDate(json['fechaIngreso']),
      identificacionConductor: parseApiString(json['identificacionConductor']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'placa': placa,
    'tipo': tipo,
    'marca': marca,
    'modelo': modelo,
    'capacidadPasajeros': capacidadPasajeros,
    'tarjetaPropiedad': tarjetaPropiedad,
    'activo': activo,
    if (tarifaId != null) 'tarifaId': tarifaId,
    if (vigenciaSoat != null) 'vigenciaSoat': formatApiDate(vigenciaSoat!),
    if (vigenciaTrm != null) 'vigenciaTrm': formatApiDate(vigenciaTrm!),
    if (fechaIngreso != null) 'fechaIngreso': formatApiDate(fechaIngreso!),
  };

  Map<String, dynamic> toJsonUpdate() => <String, dynamic>{
    if (identificacionConductor != null)
      'identificacionConductor': identificacionConductor,
    'activo': activo,
    if (vigenciaSoat != null) 'vigenciaSoat': formatApiDate(vigenciaSoat!),
    if (vigenciaTrm != null) 'vigenciaTrm': formatApiDate(vigenciaTrm!),
    if (fechaIngreso != null) 'fechaIngreso': formatApiDate(fechaIngreso!),
    if (tarifaId != null) 'tarifaId': tarifaId,
  };
}
