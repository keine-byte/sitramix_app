class ResumenDashboard {
  const ResumenDashboard({
    this.asociados,
    this.afiliaciones,
    this.conductores,
    this.sanciones,
    this.vehiculos,
    this.tarifas,
    this.planillas,
    this.despachos,
    this.pagos,
    this.mantenimientos,
  });

  final int? asociados;
  final int? afiliaciones;
  final int? conductores;

  final int? sanciones;
  final int? vehiculos;
  final int? tarifas;
  final int? planillas;
  final int? despachos;
  final int? pagos;
  final int? mantenimientos;

  static const vacio = ResumenDashboard();
}
