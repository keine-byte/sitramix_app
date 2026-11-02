import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/asociado/asociado.dart';
import 'package:sitramix/models/conductor/conductor.dart';
import 'package:sitramix/services/remote/asociados_api.dart';
import 'package:sitramix/services/remote/conductores_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> asociadoJson() => <String, dynamic>{
  'identificacion': '1099',
  'nombres': 'Ana Perez',
  'activo': true,
  'celular': '3001234567',
  'correo': 'ana@example.com',
  'fechaNacimiento': '1990-05-20',
};

void main() {
  group('AsociadosApi', () {
    test('crear omite fechaIngreso: solo se envía en el PUT', () async {
      final mock = MockApi((_) => jsonResponse(asociadoJson(), status: 201));

      await AsociadosApi(api: mock.createService(), token: 'jwt').crear(
        Asociado(
          identificacion: '1099',
          nombres: 'Ana Perez',
          activo: true,
          celular: '3001234567',
          fechaIngreso: DateTime(2026, 1, 15),
        ),
      );

      expect(mock.lastRequest.url.path, ApiPaths.asociados);
      expect(mock.lastJsonBody['identificacion'], '1099');
      expect(mock.lastJsonBody['celular'], '3001234567');
      expect(
        mock.lastJsonBody.containsKey('fechaIngreso'),
        isFalse,
        reason: 'POST /api/asociados no acepta fechaIngreso',
      );
    });

    test('actualizar envía fechaIngreso y no la clave', () async {
      final mock = MockApi((_) => jsonResponse(asociadoJson()));

      await AsociadosApi(api: mock.createService(), token: 'jwt').actualizar(
        Asociado(
          identificacion: '1099',
          nombres: 'Ana Perez',
          activo: false,
          fechaIngreso: DateTime(2026, 1, 15),
        ),
      );

      expect(mock.lastRequest.method, 'PUT');
      expect(mock.lastRequest.url.path, ApiPaths.asociado('1099'));
      expect(mock.lastJsonBody['fechaIngreso'], '2026-01-15');
      expect(mock.lastJsonBody.containsKey('identificacion'), isFalse);
      expect(mock.lastJsonBody['activo'], isFalse);
    });

    test('la credencial temporal se pide sin cuerpo', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'username': 'aperez',
          'passwordTemporal': 'Tmp12345',
        }),
      );

      final credencial = await AsociadosApi(
        api: mock.createService(),
        token: 'jwt',
      ).generarCredencialTemporal('1099');

      expect(mock.lastRequest.method, 'POST');
      expect(mock.lastRequest.url.path, ApiPaths.credencialTemporal('1099'));
      expect(mock.lastRequest.body, isEmpty);
      expect(credencial.username, 'aperez');
      expect(credencial.passwordTemporal, 'Tmp12345');
    });

    test('listar filtra por nombres y activo', () async {
      final mock = MockApi((_) => jsonResponse(const <dynamic>[]));

      await AsociadosApi(
        api: mock.createService(),
        token: 'jwt',
      ).listar(nombres: 'Ana', activo: true);

      expect(mock.lastQuery['nombres'], 'Ana');
      expect(mock.lastQuery['activo'], 'true');
      expect(mock.lastQuery['pageSize'], '50');
    });
  });

  group('ConductoresApi', () {
    test('actualizar no reenvía la identificación', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'identificacion': '1099999',
          'nombres': 'Ana Perez',
          'activo': true,
        }),
      );

      await ConductoresApi(api: mock.createService(), token: 'jwt').actualizar(
        const Conductor(
          identificacion: '1099999',
          nombres: 'Ana Perez',
          activo: true,
        ),
      );

      expect(mock.lastRequest.url.path, ApiPaths.conductor('1099999'));
      expect(mock.lastJsonBody.containsKey('identificacion'), isFalse);
      expect(mock.lastJsonBody['activo'], isTrue);
    });

    test('licenciaVencida compara la vigencia contra hoy', () {
      final vencida = Conductor(
        identificacion: '1',
        nombres: 'Vencida',
        activo: true,
        vigenciaLicencia: DateTime(2020, 1, 1),
      );
      final vigente = Conductor(
        identificacion: '2',
        nombres: 'Vigente',
        activo: true,
        vigenciaLicencia: DateTime(2099, 1, 1),
      );

      expect(vencida.licenciaVencida, isTrue);
      expect(vigente.licenciaVencida, isFalse);
    });
  });
}
