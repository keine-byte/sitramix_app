import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.body});

  final String message;

  final int? statusCode;

  final Map<String, dynamic>? body;

  String? get detail {
    final value = body?['detail'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  @override
  String toString() => message;
}

class ApiService {
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  ApiService({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 20),
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> _buildHeaders(Map<String, String>? headers) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      ...?headers,
    };
  }

  Uri _buildUrl(String path, [Map<String, String>? queryParameters]) {
    final base = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');

    return Uri.parse('$base/$normalizedPath').replace(
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final rawBody = utf8.decode(response.bodyBytes).trim();
        final decodedBody = _tryDecodeObject(rawBody);
        throw ApiException(
          _errorMessage(response.statusCode, rawBody, decodedBody),
          statusCode: response.statusCode,
          body: decodedBody,
        );
      }

      final content = utf8.decode(response.bodyBytes);

      return content.trim().isEmpty ? null : jsonDecode(content);
    } on TimeoutException {
      throw const ApiException('The request timed out.');
    } on http.ClientException {
      throw const ApiException('Could not connect to the server.');
    } on FormatException {
      throw const ApiException('The server returned an invalid response.');
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final url = _buildUrl(path, queryParameters);
    final requestHeaders = _buildHeaders(headers);

    return _send(() => _client.get(url, headers: requestHeaders));
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = _buildUrl(path);
    final requestHeaders = _buildHeaders(headers);
    final content = body == null ? null : jsonEncode(body);

    return _send(
      () => _client.post(url, headers: requestHeaders, body: content),
    );
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = _buildUrl(path);
    final requestHeaders = _buildHeaders(headers);
    final content = body == null ? null : jsonEncode(body);

    return _send(
      () => _client.put(url, headers: requestHeaders, body: content),
    );
  }

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = _buildUrl(path);
    final requestHeaders = _buildHeaders(headers);
    final content = body == null ? null : jsonEncode(body);

    return _send(
      () => _client.delete(url, headers: requestHeaders, body: content),
    );
  }
}

Map<String, dynamic>? _tryDecodeObject(String raw) {
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

String _errorMessage(int statusCode, String raw, Map<String, dynamic>? json) {
  final prefix = 'Error HTTP $statusCode';

  if (json != null) {
    final detail = json['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();

    final errors = json['errors'];
    if (errors is Map) {
      final messages = <String>[];
      for (final value in errors.values) {
        if (value is List) {
          for (final item in value) {
            if (item is String && item.trim().isNotEmpty) {
              messages.add(item.trim());
            }
          }
        } else if (value is String && value.trim().isNotEmpty) {
          messages.add(value.trim());
        }
      }
      if (messages.isNotEmpty) return messages.join(' ');
    }

    for (final key in const <String>['mensaje', 'message', 'error']) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }

    final title = json['title'];
    if (title is String && title.trim().isNotEmpty) return title.trim();
  }

  return raw.isEmpty ? prefix : '$prefix: $raw';
}
