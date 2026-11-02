import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/common/json_utils.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/pago/pago.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class PagosApi extends AuthenticatedApi {
  PagosApi({required super.api, super.token});

  Future<List<Pago>> listar({
    PageQuery query = const PageQuery(),
    int? numeroPlanilla,
    String? placa,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final json = await api.get(
      ApiPaths.pagos,
      queryParameters: query.toQueryParameters()
        ..addAll(<String, String>{
          if (numeroPlanilla != null) 'numeroPlanilla': '$numeroPlanilla',
          if (placa != null && placa.isNotEmpty) 'placa': placa,
          if (desde != null) 'desde': formatApiDate(desde),
          if (hasta != null) 'hasta': formatApiDate(hasta),
        }),
      headers: authHeaders,
    );
    return parseJsonList(json, Pago.fromJson);
  }

  Future<Pago> consultar(int id) async {
    final json = await api.get(ApiPaths.pago(id), headers: authHeaders);
    return parseJsonObject(json, Pago.fromJson);
  }

  Future<Pago> registrar(Pago pago) async {
    final json = await api.post(
      ApiPaths.pagos,
      body: pago.toJson(),
      headers: authHeaders,
    );
    return parseJsonObject(json, Pago.fromJson);
  }
}
