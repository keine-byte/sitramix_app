import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/conductor/conductor.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class ConductoresApi extends AuthenticatedApi {
  ConductoresApi({required super.api, super.token});

  Future<List<Conductor>> listar({
    PageQuery query = const PageQuery(),
    String? nombres,
    bool? activo,
  }) async {
    final json = await api.get(
      ApiPaths.conductores,
      queryParameters: query.toQueryParameters()
        ..addAll(<String, String>{
          if (nombres != null && nombres.isNotEmpty) 'nombres': nombres,
          if (activo != null) 'activo': '$activo',
        }),
      headers: authHeaders,
    );
    return parseJsonList(json, Conductor.fromJson);
  }

  Future<Conductor> consultar(String identificacion) async {
    final json = await api.get(
      ApiPaths.conductor(identificacion),
      headers: authHeaders,
    );
    return parseJsonObject(json, Conductor.fromJson);
  }

  Future<Conductor> crear(Conductor conductor) async {
    final json = await api.post(
      ApiPaths.conductores,
      body: conductor.toJson(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Conductor.fromJson);
  }

  Future<Conductor> actualizar(Conductor conductor) async {
    final json = await api.put(
      ApiPaths.conductor(conductor.identificacion),
      body: conductor.toJsonUpdate(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Conductor.fromJson);
  }
}
