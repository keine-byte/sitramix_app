import 'package:sitramix/services/remote/api_service.dart';

abstract class AuthenticatedApi {
  AuthenticatedApi({required this.api, this.token});

  final ApiService api;
  final String? token;

  Map<String, String> get authHeaders {
    final current = token?.trim();
    if (current == null || current.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $current'};
  }
}

Object? desenvuelveRespuestaApi(Object? json) {
  if (json is Map<String, dynamic> &&
      json.containsKey('data') &&
      (json.containsKey('success') || json.containsKey('message'))) {
    return json['data'];
  }
  return json;
}

List<T> parseJsonList<T>(
  Object? json,
  T Function(Map<String, dynamic>) fromJson,
) {
  final contenido = desenvuelveRespuestaApi(json);
  final filas = contenido is Map<String, dynamic> && contenido['items'] is List
      ? contenido['items']
      : contenido;

  if (filas is! List) {
    throw const ApiException('La respuesta del servidor no es una lista.');
  }
  return filas
      .whereType<Map<String, dynamic>>()
      .map(fromJson)
      .toList(growable: false);
}

T parseJsonObject<T>(Object? json, T Function(Map<String, dynamic>) fromJson) {
  final contenido = desenvuelveRespuestaApi(json);
  if (contenido is! Map<String, dynamic>) {
    throw const ApiException(
      'La respuesta del servidor no es un objeto válido.',
    );
  }
  return fromJson(contenido);
}
