import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/sesion/sesion.dart';
import 'package:sitramix/services/remote/auth_api.dart';

import 'helpers/mock_api.dart';

void main() {
  group('AuthApi', () {
    test('login envía username/password y no manda Authorization', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'token': 'jwt-asistente',
          'rol': 'ASISTENTE',
          'requiereCambioPassword': false,
        }),
      );

      final sesion = await AuthApi(api: mock.createService())
          .login(username: 'ana', password: 'secreta');

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

    test('con requiereCambioPassword el token queda restringido', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'token': 'solo-cambio',
          'rol': 'GERENTE',
          'requiereCambioPassword': true,
        }),
      );

      final sesion = await AuthApi(api: mock.createService())
          .login(username: 'jefe', password: 'Temporal123');

      expect(sesion.requiereCambioPassword, isTrue);
      expect(sesion.token, 'solo-cambio');
      expect(sesion.rol, Rol.gerente);
      expect(
        sesion.tieneAcceso,
        isFalse,
        reason: 'el token restringido solo sirve para cambiar-password',
      );
    });

    test(
      'cambiarPassword usa el token restringido, no el de negocio',
      () async {
        final mock = MockApi(
          (_) => jsonResponse(<String, dynamic>{
            'token': 'jwt-definitivo',
            'rol': 'GERENTE',
            'requiereCambioPassword': false,
          }),
        );

        final sesion =
            await AuthApi(
              api: mock.createService(),
              token: 'jwt-negocio',
            ).cambiarPassword(
              nuevaPassword: 'ClaveSegura2026',
              confirmacionPassword: 'ClaveSegura2026',
              tokenCambio: 'solo-cambio',
            );

        expect(mock.lastRequest.url.path, ApiPaths.cambiarPassword);
        expect(mock.lastRequest.headers['authorization'], 'Bearer solo-cambio');
        expect(mock.lastJsonBody, <String, dynamic>{
          'nuevaPassword': 'ClaveSegura2026',
          'confirmacionPassword': 'ClaveSegura2026',
        });
        expect(sesion.token, 'jwt-definitivo');
        expect(sesion.requiereCambioPassword, isFalse);
      },
    );

    test('registrarUsuario envía el rol de la API y el estado', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'token': 'jwt-nuevo',
          'rol': 'ASOCIADO',
        }, status: 201),
      );

      final sesion =
          await AuthApi(
            api: mock.createService(),
            token: 'jwt-gerente',
          ).registrarUsuario(
            identificacion: '1099',
            nombres: 'Ana Perez',
            username: 'aperez',
            password: 'ClaveSegura2026',
            rol: Rol.asociado,
          );

      expect(mock.lastRequest.headers['authorization'], 'Bearer jwt-gerente');
      expect(mock.lastJsonBody['rol'], 'ASOCIADO');
      expect(mock.lastJsonBody['activo'], isTrue);
      expect(mock.lastJsonBody['identificacion'], '1099');
      expect(sesion.rol, Rol.asociado);
      expect(sesion.esAsociado, isTrue);
    });

    test('un rol desconocido no rompe el parseo', () {
      final sesion = Sesion.fromJson(<String, dynamic>{
        'token': 'x',
        'rol': 'SUPERVISOR',
      });

      expect(sesion.rol, Rol.desconocido);
      expect(sesion.requiereCambioPassword, isFalse);
    });
  });
}
