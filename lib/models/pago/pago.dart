import 'package:sitramix/models/common/json_utils.dart';

class Pago {
  const Pago({
    this.id,
    required this.numeroPlanilla,
    this.valorPagado = 0,
    this.fechaPago,
    this.registradoPor,
    this.fechaRegistro,
  });

  final int? id;
  final int numeroPlanilla;
  final double valorPagado;
  final DateTime? fechaPago;
  final String? registradoPor;
  final DateTime? fechaRegistro;

  factory Pago.fromJson(Map<String, dynamic> json) => Pago(
    id: parseApiInt(json['id']),
    numeroPlanilla: parseApiInt(json['numeroPlanilla']) ?? 0,
    valorPagado: parseApiDouble(json['valorPagado']) ?? 0,
    fechaPago: parseApiDate(json['fechaPago']),
    registradoPor: parseApiString(json['registradoPor']),
    fechaRegistro: parseApiDate(json['fechaRegistro']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'numeroPlanilla': numeroPlanilla,
    if (fechaPago != null) 'fechaPago': formatApiDate(fechaPago!),
  };
}
