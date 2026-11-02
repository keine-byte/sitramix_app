import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/config/app_config.dart';
import 'package:sitramix/models/login/login_request.dart';
import 'package:sitramix/models/sesion/sesion.dart';
import 'package:sitramix/services/remote/api_service.dart';
import 'package:sitramix/services/remote/login_service.dart';

import 'helpers/mock_api.dart';

void main() {
  group('LoginRequest', () {
    test('envía username y nunca email, como espera SITRAM', () {
      final body = const LoginRequest(
        username: 'ana',
        password: 'secreta',
      ).toJson();

      expect(body, <String, dynamic>{'username': 'ana', 'password': 'secreta'});
      expect(body.containsKey('email'), isFalse);
    });
  });

  group('LoginService', () {
    test('pega en ApiPaths.login con el cuerpo del DTO', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'token': 'jwt-asistente',
          'rol': 'ASISTENTE',
          'requiereCambioPassword': false,
        }),
      );

      final sesion = await LoginService(api: mock.createService())
          .login(const LoginRequest(username: 'ana', password: 'secreta'));

      expect(mock.lastRequest.method, 'POST');
      expect(mock.lastRequest.url.path, ApiPaths.login);
      expect(mock.lastJsonBody, <String, dynamic>{
        'username': 'ana',
        'password': 'secreta',
      });
      expect(mock.lastRequest.headers.containsKey('authorization'), isFalse);
      expect(sesion.token, 'jwt-asistente');
      expect(sesion.rol, Rol.asistente);
      expect(sesion.tieneAcceso, isTrue);
    });

    test(
      'la base URL por defecto es la de AppConfig, no la de otro producto',
      () {
        final service = LoginService();

        expect(service.apiBaseUrl, AppConfig.apiBaseUrl);
        expect(service.apiBaseUrl, isNot(contains('smartbooks')));
      },
    );

    test('un 401 se propaga como ApiException con statusCode', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'mensaje': 'Credenciales inválidas',
        }, status: 401),
      );

      final service = LoginService(api: mock.createService());

      await expectLater(
        service.login(const LoginRequest(username: 'ana', password: 'mala')),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having(
                (error) => error.message,
                'message',
                contains('Credenciales inválidas'),
              ),
        ),
      );
    });

    test('una respuesta que no es objeto falla con ApiException', () async {
      final mock = MockApi((_) => jsonResponse(<dynamic>[]));

      await expectLater(
        LoginService(api: mock.createService())
            .login(const LoginRequest(username: 'ana', password: 'secreta')),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
