import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/services/remote/api_service.dart';

import 'helpers/mock_api.dart';

void main() {
  group('ApiService', () {
    test('normaliza la base URL y agrega las cabeceras JSON', () async {
      final mock = MockApi((_) => jsonResponse(<String, dynamic>{'ok': true}));

      final result = await mock
          .createService('https://api.sitram.test/')
          .get('/api/tarifas');

      expect(result, <String, dynamic>{'ok': true});
      expect(mock.lastRequest.method, 'GET');
      expect(
        mock.lastRequest.url.toString(),
        'https://api.sitram.test/api/tarifas',
      );
      expect(mock.lastRequest.headers['accept'], 'application/json');
      expect(
        mock.lastRequest.headers['content-type'],
        'application/json; charset=UTF-8',
      );
    });

    test('serializa la query de paginación y filtros', () async {
      final mock = MockApi((_) => jsonResponse(const <dynamic>[]));

      await mock.createService().get(
        ApiPaths.planillas,
        queryParameters: <String, String>{
          'page': '2',
          'pageSize': '25',
          'estado': 'ACTIVA',
        },
      );

      expect(mock.lastRequest.url.path, '/api/planillas');
      expect(mock.lastQuery, <String, String>{
        'page': '2',
        'pageSize': '25',
        'estado': 'ACTIVA',
      });
    });

    test('DELETE envía cuerpo cuando se lo pasan', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{'estado': 'CANCELADO'}),
      );

      final result = await mock.createService().delete(
        ApiPaths.despacho(7),
        body: <String, dynamic>{'motivo': 'Clima adverso'},
      );

      expect(mock.lastRequest.method, 'DELETE');
      expect(mock.lastRequest.url.path, '/api/despachos/7');
      expect(jsonDecode(mock.lastRequest.body), <String, dynamic>{
        'motivo': 'Clima adverso',
      });
      expect(result, <String, dynamic>{'estado': 'CANCELADO'});
    });

    test('un 204 sin cuerpo devuelve null', () async {
      final mock = MockApi((_) => emptyResponse());

      final result = await mock.createService().delete(ApiPaths.tarifa(3));

      expect(result, isNull);
    });

    test(
      'POST sin cuerpo no envía body pero conserva el Authorization',
      () async {
        final mock = MockApi(
          (_) => jsonResponse(<String, dynamic>{
            'username': 'ana',
            'passwordTemporal': 'Xyz12345',
          }),
        );

        await mock.createService().post(
          ApiPaths.credencialTemporal('1099'),
          headers: <String, String>{'Authorization': 'Bearer jwt'},
        );

        expect(mock.lastRequest.method, 'POST');
        expect(mock.lastRequest.body, isEmpty);
        expect(mock.lastRequest.headers['authorization'], 'Bearer jwt');
      },
    );

    test('las respuestas no 2xx se convierten en ApiException', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'mensaje': 'La planilla ya tiene un pago.',
        }, status: 409),
      );

      await expectLater(
        mock.createService().post(
          ApiPaths.pagos,
          body: <String, dynamic>{'numeroPlanilla': 25},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                (e) => e.message,
                'message',
                contains('ya tiene un pago'),
              ),
        ),
      );
    });

    test('un cuerpo inválido se reporta como respuesta inválida', () async {
      final mock = MockApi(
        (_) => http.Response('no-es-json', 200, headers: jsonHeaders),
      );

      await expectLater(
        mock.createService().get(ApiPaths.tarifas),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'The server returned an invalid response.',
          ),
        ),
      );
    });

    test('extrae detail del Problem Details que responde SITRAM', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'type': 'https://tools.ietf.org/html/rfc9110#section-15.5.1',
          'title': 'No fue posible procesar la solicitud',
          'status': 401,
          'detail': 'Usuario o contraseña incorrectos',
          'instance': '/api/auth/login',
        }, status: 401),
      );

      await expectLater(
        mock.createService().post(
          ApiPaths.login,
          body: <String, dynamic>{'username': 'aperez', 'password': 'mala'},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.message,
                'message',
                'Usuario o contraseña incorrectos',
              )
              .having(
                (e) => e.detail,
                'detail',
                'Usuario o contraseña incorrectos',
              )
              .having(
                (e) => e.body?['instance'],
                'instance',
                '/api/auth/login',
              ),
        ),
      );
    });

    test('los errores de validación se leen del mapa errors', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'status': 400,
          'errors': <String, dynamic>{
            'Username': <String>['The Username field is required.'],
            'Password': <String>['The Password field is required.'],
          },
        }, status: 400),
      );

      await expectLater(
        mock.createService().post(ApiPaths.login, body: <String, dynamic>{}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.message,
                'message',
                'The Username field is required. '
                    'The Password field is required.',
              )
              .having((e) => e.detail, 'detail', isNull),
        ),
      );
    });

    test('un cuerpo de error que no es JSON conserva el texto crudo', () async {
      final mock = MockApi(
        (_) => http.Response('<html>502 Bad Gateway</html>', 502),
      );

      await expectLater(
        mock.createService().get(ApiPaths.tarifas),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Error HTTP 502: <html>502 Bad Gateway</html>',
          ),
        ),
      );
    });
  });
}
