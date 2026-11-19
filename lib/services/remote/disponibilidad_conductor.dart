import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/sancion/sancion.dart';
import 'package:sitramix/services/remote/api_service.dart';
import 'package:sitramix/services/remote/sanciones_api.dart';
import 'package:sitramix/services/remote/vehiculos_api.dart';

/// Reglas de disponibilidad del conductor compartidas por los formularios.
///
/// El backend rechaza planillas de conductores sancionados; estas consultas
/// permiten avisar antes de enviar la solicitud y cubren también despachos y
/// la asignación de vehículos, que no tienen esa validación en el servidor.
class DisponibilidadConductor {
  DisponibilidadConductor({required ApiService api, this.token})
    : _sanciones = SancionesApi(api: api, token: token),
      _vehiculos = VehiculosApi(api: api, token: token);

  final SancionesApi _sanciones;
  final VehiculosApi _vehiculos;

  /// Token usado por las consultas (se expone para las pruebas).
  final String? token;

  /// Conductor asignado a [placa], o `null` si el vehículo no existe todavía
  /// o no tiene conductor.
  Future<String?> conductorDeVehiculo(String placa) async {
    if (placa.trim().isEmpty) return null;
    try {
      final vehiculo = await _vehiculos.consultar(placa.trim());
      final identificacion = vehiculo.identificacionConductor?.trim();
      return identificacion == null || identificacion.isEmpty
          ? null
          : identificacion;
    } on ApiException {
      // Un vehículo inexistente (404) no tiene conductor que validar.
      return null;
    }
  }

  /// Sanción ACTIVA del conductor que cubre [fecha], si existe.
  Future<Sancion?> sancionVigente(String identificacion, DateTime fecha) async {
    if (identificacion.trim().isEmpty) return null;
    final sanciones = await _sanciones.listar(
      query: const PageQuery(pageSize: 100),
      conductor: identificacion.trim(),
      estado: EstadoSancion.activa,
    );
    for (final sancion in sanciones) {
      if (sancion.cubre(fecha)) return sancion;
    }
    return null;
  }

  /// Sanción vigente del conductor asignado a [placa], si existe.
  Future<Sancion?> sancionDeVehiculo(String placa, DateTime fecha) async {
    final identificacion = await conductorDeVehiculo(placa);
    if (identificacion == null) return null;
    return sancionVigente(identificacion, fecha);
  }
}

/// Texto de bloqueo mostrado cuando el conductor está sancionado.
String mensajeConductorSancionado(
  Sancion sancion, {
  required String identificacion,
}) {
  final desde = sancion.fechaInicio;
  final hasta = sancion.fechaFin;
  final periodo = desde == null || hasta == null
      ? ''
      : ' (del ${_fechaCorta(desde)} al ${_fechaCorta(hasta)})';
  return 'El conductor $identificacion tiene una sanción ACTIVA: '
      '${sancion.motivo}$periodo. No puede asignarse a nuevas operaciones '
      'mientras la sanción esté vigente.';
}

String _fechaCorta(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/'
    '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
