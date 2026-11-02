import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/sancion/sancion.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class SancionesApi extends AuthenticatedApi {
  SancionesApi({required super.api, super.token});

  Future<List<Sancion>> listar({
    PageQuery query = const PageQuery(),
    String? conductor,
    EstadoSancion? estado,
  }) async {
    final json = await api.get(
      ApiPaths.sanciones,
      queryParameters: query.toQueryParameters()
        ..addAll(<String, String>{
          if (conductor != null && conductor.isNotEmpty) 'conductor': conductor,
          if (estado != null) 'estado': estado.apiValue,
        }),
      headers: authHeaders,
    );
    return parseJsonList(json, Sancion.fromJson);
  }

  Future<Sancion> consultar(int id) async {
    final json = await api.get(ApiPaths.sancion(id), headers: authHeaders);
    return parseJsonObject(json, Sancion.fromJson);
  }

  Future<Sancion> crear(Sancion sancion) async {
    final json = await api.post(
      ApiPaths.sanciones,
      body: sancion.toJson(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Sancion.fromJson);
  }

  Future<Sancion> actualizar(Sancion sancion) async {
    final id = sancion.id;
    if (id == null) {
      throw ArgumentError('La sanción debe tener id para actualizarse.');
    }
    final json = await api.put(
      ApiPaths.sancion(id),
      body: sancion.toJsonUpdate(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Sancion.fromJson);
  }
}
