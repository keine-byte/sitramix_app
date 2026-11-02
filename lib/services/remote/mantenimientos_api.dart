import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/common/json_utils.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/mantenimiento/mantenimiento.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class MantenimientosApi extends AuthenticatedApi {
  MantenimientosApi({required super.api, super.token});

  Future<List<Mantenimiento>> listar({
    PageQuery query = const PageQuery(),
    String? placa,
    EstadoMantenimiento? estado,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final json = await api.get(
      ApiPaths.mantenimientos,
      queryParameters: query.toQueryParameters()
        ..addAll(<String, String>{
          if (placa != null && placa.isNotEmpty) 'placa': placa,
          if (estado != null) 'estado': estado.apiValue,
          if (desde != null) 'desde': formatApiDateTime(desde),
          if (hasta != null) 'hasta': formatApiDateTime(hasta),
        }),
      headers: authHeaders,
    );
    return parseJsonList(json, Mantenimiento.fromJson);
  }

  Future<Mantenimiento> consultar(int id) async {
    final json = await api.get(
      ApiPaths.mantenimiento(id),
      headers: authHeaders,
    );
    return parseJsonObject(json, Mantenimiento.fromJson);
  }

  Future<Mantenimiento> registrarIngreso(Mantenimiento mantenimiento) async {
    final json = await api.post(
      ApiPaths.mantenimientos,
      body: mantenimiento.toJson(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Mantenimiento.fromJson);
  }

  Future<Mantenimiento> registrarSalida(
    int id, {
    required DateTime fechaSalida,
    required String observaciones,
  }) async {
    final json = await api.put(
      ApiPaths.mantenimiento(id),
      body: mantenimientoSalidaBody(
        fechaSalida: fechaSalida,
        observaciones: observaciones,
      ),
      headers: authHeaders,
    );
    return parseJsonObject(json, Mantenimiento.fromJson);
  }
}
