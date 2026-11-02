import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/common/json_utils.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/despacho/despacho.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class DespachosApi extends AuthenticatedApi {
  DespachosApi({required super.api, super.token});

  Future<List<Despacho>> listar({
    PageQuery query = const PageQuery(),
    DateTime? fecha,
    String? vehiculo,
    String? ruta,
  }) async {
    final json = await api.get(
      ApiPaths.despachos,
      queryParameters: query.toQueryParameters()
        ..addAll(<String, String>{
          if (fecha != null) 'fecha': formatApiDate(fecha),
          if (vehiculo != null && vehiculo.isNotEmpty) 'vehiculo': vehiculo,
          if (ruta != null && ruta.isNotEmpty) 'ruta': ruta,
        }),
      headers: authHeaders,
    );
    return parseJsonList(json, Despacho.fromJson);
  }

  Future<Despacho> consultar(int id) async {
    final json = await api.get(ApiPaths.despacho(id), headers: authHeaders);
    return parseJsonObject(json, Despacho.fromJson);
  }

  Future<Despacho> crear(Despacho despacho) async {
    final json = await api.post(
      ApiPaths.despachos,
      body: despacho.toJson(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Despacho.fromJson);
  }

  Future<Despacho> cancelar(int id, {required String motivo}) async {
    final json = await api.delete(
      ApiPaths.despacho(id),
      body: <String, dynamic>{'motivo': motivo},
      headers: authHeaders,
    );
    return parseJsonObject(json, Despacho.fromJson);
  }
}
