import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/afiliacion/afiliacion.dart';
import 'package:sitramix/models/common/json_utils.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class AfiliacionesApi extends AuthenticatedApi {
  AfiliacionesApi({required super.api, super.token});

  Future<List<Afiliacion>> listar({
    PageQuery query = const PageQuery(),
    String? asociado,
    String? vehiculo,
    EstadoAfiliacion? estado,
  }) async {
    final json = await api.get(
      ApiPaths.afiliaciones,
      queryParameters: query.toQueryParameters()
        ..addAll(<String, String>{
          if (asociado != null && asociado.isNotEmpty) 'asociado': asociado,
          if (vehiculo != null && vehiculo.isNotEmpty) 'vehiculo': vehiculo,
          if (estado != null) 'estado': estado.apiValue,
        }),
      headers: authHeaders,
    );
    return parseJsonList(json, Afiliacion.fromJson);
  }

  Future<Afiliacion> consultar(int id) async {
    final json = await api.get(ApiPaths.afiliacion(id), headers: authHeaders);
    return parseJsonObject(json, Afiliacion.fromJson);
  }

  Future<Afiliacion> crear(Afiliacion afiliacion) async {
    final json = await api.post(
      ApiPaths.afiliaciones,
      body: afiliacion.toJson(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Afiliacion.fromJson);
  }

  Future<Afiliacion> actualizar(Afiliacion afiliacion) async {
    final id = afiliacion.id;
    if (id == null) {
      throw ArgumentError('La afiliación debe tener id para actualizarse.');
    }
    final json = await api.put(
      ApiPaths.afiliacion(id),
      body: afiliacion.toJson(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Afiliacion.fromJson);
  }

  Future<Afiliacion> finalizar(int id, {DateTime? fechaFinAfiliacion}) async {
    final json = await api.delete(
      ApiPaths.afiliacion(id),
      body: <String, dynamic>{
        'fechaFinAfiliacion': fechaFinAfiliacion == null
            ? null
            : formatApiDate(fechaFinAfiliacion),
      },
      headers: authHeaders,
    );
    return parseJsonObject(json, Afiliacion.fromJson);
  }
}
