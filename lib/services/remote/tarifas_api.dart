import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/tarifa/tarifa.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class TarifasApi extends AuthenticatedApi {
  TarifasApi({required super.api, super.token});

  Future<List<Tarifa>> listar({
    PageQuery query = const PageQuery(),
    bool? activo,
  }) async {
    final json = await api.get(
      ApiPaths.tarifas,
      queryParameters: query.toQueryParameters()
        ..addAll(<String, String>{if (activo != null) 'activo': '$activo'}),
      headers: authHeaders,
    );
    return parseJsonList(json, Tarifa.fromJson);
  }

  Future<Tarifa> consultar(int id) async {
    final json = await api.get(ApiPaths.tarifa(id), headers: authHeaders);
    return parseJsonObject(json, Tarifa.fromJson);
  }

  Future<Tarifa> crear(Tarifa tarifa) async {
    final json = await api.post(
      ApiPaths.tarifas,
      body: tarifa.toJson(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Tarifa.fromJson);
  }

  Future<Tarifa> inactivar(int id) async {
    final json = await api.delete(ApiPaths.tarifa(id), headers: authHeaders);
    return parseJsonObject(json, Tarifa.fromJson);
  }
}
