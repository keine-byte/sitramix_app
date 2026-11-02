import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sitramix/services/remote/api_service.dart';

const Map<String, String> jsonHeaders = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

http.Response jsonResponse(Object? body, {int status = 200}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: jsonHeaders,
    );

http.Response emptyResponse([int status = 204]) =>
    http.Response.bytes(const <int>[], status);

class MockApi {
  MockApi(this._respond);

  static const String baseUrl = 'https://api.sitram.test';

  final http.Response Function(http.Request request) _respond;

  final List<http.Request> requests = <http.Request>[];

  late final http.Client client = MockClient((http.Request request) async {
    requests.add(request);
    return _respond(request);
  });

  ApiService createService([String? url]) => ApiService(
    baseUrl: url ?? baseUrl,
    timeout: const Duration(seconds: 5),
    client: client,
  );

  http.Request get lastRequest => requests.last;

  http.Request ultimaCon(String metodo) =>
      requests.lastWhere((request) => request.method == metodo);

  Map<String, String> get lastQuery => lastRequest.url.queryParameters;

  Map<String, dynamic> get lastJsonBody => jsonBody(lastRequest);

  Map<String, dynamic> jsonBody(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;
}
