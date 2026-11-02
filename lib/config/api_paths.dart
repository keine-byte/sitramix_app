class ApiPaths {
  const ApiPaths._();

  static const String login = '/api/auth/login';
  static const String cambiarPassword = '/api/auth/cambiar-password';
  static const String registrarUsuario = '/api/auth/registrar';

  static const String asociados = '/api/asociados';

  static String asociado(String identificacion) =>
      '/api/asociados/$identificacion';

  static String credencialTemporal(String identificacion) =>
      '/api/asociados/$identificacion/credencial-temporal';

  static const String conductores = '/api/conductores';

  static String conductor(String identificacion) =>
      '/api/conductores/$identificacion';

  static const String vehiculos = '/api/vehiculos';

  static String vehiculo(String placa) => '/api/vehiculos/$placa';

  static const String afiliaciones = '/api/afiliaciones';

  static String afiliacion(int id) => '/api/afiliaciones/$id';

  static const String tarifas = '/api/tarifas';

  static String tarifa(int id) => '/api/tarifas/$id';

  static const String planillas = '/api/planillas';
  static const String planillasMasivas = '/api/planillas/masivas';

  static String planilla(int numero) => '/api/planillas/$numero';

  static const String despachos = '/api/despachos';

  static String despacho(int id) => '/api/despachos/$id';

  static const String sanciones = '/api/sanciones';

  static String sancion(int id) => '/api/sanciones/$id';

  static const String miCuentaVehiculos = '/api/mi-cuenta/vehiculos';
  static const String miCuentaViajes = '/api/mi-cuenta/viajes';
  static const String miCuentaDespachos = '/api/mi-cuenta/despachos';

  static const String pagos = '/api/pagos';

  static String pago(int id) => '/api/pagos/$id';

  static const String mantenimientos = '/api/mantenimientos';

  static String mantenimiento(int id) => '/api/mantenimientos/$id';
}
