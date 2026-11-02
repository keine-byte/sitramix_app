import 'package:sitramix/models/common/json_utils.dart';

class Tarifa {
  const Tarifa({
    this.id,
    required this.aportesGastosVarios,
    required this.fondoReposicion,
    required this.aporteSocialSocio,
    this.total,
    required this.activo,
  });

  final int? id;
  final double aportesGastosVarios;
  final double fondoReposicion;
  final double aporteSocialSocio;
  final double? total;
  final bool activo;

  factory Tarifa.fromJson(Map<String, dynamic> json) => Tarifa(
    id: parseApiInt(json['id']),
    aportesGastosVarios: parseApiDouble(json['aportesGastosVarios']) ?? 0,
    fondoReposicion: parseApiDouble(json['fondoReposicion']) ?? 0,
    aporteSocialSocio: parseApiDouble(json['aporteSocialSocio']) ?? 0,
    total: parseApiDouble(json['total']),
    activo: parseApiBool(json['activo']) ?? true,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'aportesGastosVarios': aportesGastosVarios,
    'fondoReposicion': fondoReposicion,
    'aporteSocialSocio': aporteSocialSocio,
    'activo': activo,
  };
}
