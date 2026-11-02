import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/vehiculo/vehiculo.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class VehiculosApi extends AuthenticatedApi {
  VehiculosApi({required super.api, super.token});

  Future<List<Vehiculo>> listar({
    PageQuery query = const PageQuery(),
    String? placa,
    String? tipo,
  }) async {
    final json = await api.get(
      ApiPaths.vehiculos,
      queryParameters: query.toQueryParameters()
        ..addAll(<String, String>{
          if (placa != null && placa.isNotEmpty) 'placa': placa,
          if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
        }),
      headers: authHeaders,
    );
    return parseJsonList(json, Vehiculo.fromJson);
  }

  Future<Vehiculo> consultar(String placa) async {
    final json = await api.get(ApiPaths.vehiculo(placa), headers: authHeaders);
    return parseJsonObject(json, Vehiculo.fromJson);
  }

  Future<Vehiculo> crear(Vehiculo vehiculo) async {
    final json = await api.post(
      ApiPaths.vehiculos,
      body: vehiculo.toJson(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Vehiculo.fromJson);
  }

  Future<Vehiculo> actualizar(Vehiculo vehiculo) async {
    final json = await api.put(
      ApiPaths.vehiculo(vehiculo.placa),
      body: vehiculo.toJsonUpdate(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Vehiculo.fromJson);
  }

  Future<Vehiculo> asignarConductor({
    required String placa,
    required String identificacionConductor,
  }) async {
    final json = await api.put(
      ApiPaths.vehiculo(placa),
      body: <String, dynamic>{
        'identificacionConductor': identificacionConductor,
      },
      headers: authHeaders,
    );
    return parseJsonObject(json, Vehiculo.fromJson);
  }
}
