import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/common/json_utils.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/planilla/planilla.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class PlanillasApi extends AuthenticatedApi {
  PlanillasApi({required super.api, super.token});

  Future<List<Planilla>> listar({
    PageQuery query = const PageQuery(),
    DateTime? fecha,
    String? vehiculo,
    EstadoPlanilla? estado,
  }) async {
    final json = await api.get(
      ApiPaths.planillas,
      queryParameters: query.toQueryParameters()
        ..addAll(<String, String>{
          if (fecha != null) 'fecha': formatApiDate(fecha),
          if (vehiculo != null && vehiculo.isNotEmpty) 'vehiculo': vehiculo,
          if (estado != null) 'estado': estado.apiValue,
        }),
      headers: authHeaders,
    );
    return parseJsonList(json, Planilla.fromJson);
  }

  Future<Planilla> consultar(int numero) async {
    final json = await api.get(ApiPaths.planilla(numero), headers: authHeaders);
    return parseJsonObject(json, Planilla.fromJson);
  }

  Future<Planilla> crear(Planilla planilla) async {
    final json = await api.post(
      ApiPaths.planillas,
      body: planilla.toJson(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Planilla.fromJson);
  }

  Future<InformePlanillasMasivas> crearMasivas(
    PlanillaMasivaRequest request,
  ) async {
    final json = await api.post(
      ApiPaths.planillasMasivas,
      body: request.toJson(),
      headers: authHeaders,
    );
    return parseJsonObject(json, InformePlanillasMasivas.fromJson);
  }

  Future<Planilla> anular(int numero) async {
    final json = await api.delete(
      ApiPaths.planilla(numero),
      headers: authHeaders,
    );
    return parseJsonObject(json, Planilla.fromJson);
  }
}
