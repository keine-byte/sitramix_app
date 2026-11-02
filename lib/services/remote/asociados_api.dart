import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/asociado/asociado.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class AsociadosApi extends AuthenticatedApi {
  AsociadosApi({required super.api, super.token});

  Future<List<Asociado>> listar({
    PageQuery query = const PageQuery(),
    String? nombres,
    bool? activo,
  }) async {
    final json = await api.get(
      ApiPaths.asociados,
      queryParameters: query.toQueryParameters()
        ..addAll(<String, String>{
          if (nombres != null && nombres.isNotEmpty) 'nombres': nombres,
          if (activo != null) 'activo': '$activo',
        }),
      headers: authHeaders,
    );
    return parseJsonList(json, Asociado.fromJson);
  }

  Future<Asociado> consultar(String identificacion) async {
    final json = await api.get(
      ApiPaths.asociado(identificacion),
      headers: authHeaders,
    );
    return parseJsonObject(json, Asociado.fromJson);
  }

  Future<Asociado> crear(Asociado asociado) async {
    final json = await api.post(
      ApiPaths.asociados,
      body: asociado.toJson(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Asociado.fromJson);
  }

  Future<Asociado> actualizar(Asociado asociado) async {
    final json = await api.put(
      ApiPaths.asociado(asociado.identificacion),
      body: asociado.toJsonUpdate(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Asociado.fromJson);
  }

  Future<CredencialTemporal> generarCredencialTemporal(
    String identificacion,
  ) async {
    final json = await api.post(
      ApiPaths.credencialTemporal(identificacion),
      headers: authHeaders,
    );
    return parseJsonObject(json, CredencialTemporal.fromJson);
  }
}
