import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/common/json_utils.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/despacho/despacho.dart';
import 'package:sitramix/models/planilla/planilla.dart';
import 'package:sitramix/models/vehiculo/vehiculo.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class MiCuentaApi extends AuthenticatedApi {
  MiCuentaApi({required super.api, super.token});

  Future<List<Vehiculo>> vehiculos() async {
    final json = await api.get(
      ApiPaths.miCuentaVehiculos,
      headers: authHeaders,
    );
    return parseJsonList(json, Vehiculo.fromJson);
  }

  Future<List<Planilla>> viajes({
    PageQuery query = const PageQuery(),
    DateTime? desde,
    DateTime? hasta,
    String? placa,
  }) async {
    final json = await api.get(
      ApiPaths.miCuentaViajes,
      queryParameters: query.toQueryParameters()
        ..addAll(<String, String>{
          if (desde != null) 'desde': formatApiDate(desde),
          if (hasta != null) 'hasta': formatApiDate(hasta),
          if (placa != null && placa.isNotEmpty) 'placa': placa,
        }),
      headers: authHeaders,
    );
    return parseJsonList(json, Planilla.fromJson);
  }

  Future<List<Despacho>> despachos({
    PageQuery query = const PageQuery(),
    DateTime? desde,
    DateTime? hasta,
    String? placa,
    String? ruta,
  }) async {
    final json = await api.get(
      ApiPaths.miCuentaDespachos,
      queryParameters: query.toQueryParameters()
        ..addAll(<String, String>{
          if (desde != null) 'desde': formatApiDate(desde),
          if (hasta != null) 'hasta': formatApiDate(hasta),
          if (placa != null && placa.isNotEmpty) 'placa': placa,
          if (ruta != null && ruta.isNotEmpty) 'ruta': ruta,
        }),
      headers: authHeaders,
    );
    return parseJsonList(json, Despacho.fromJson);
  }
}
