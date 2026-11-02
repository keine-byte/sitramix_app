import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/afiliacion/afiliacion.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/tarifa/tarifa.dart';
import 'package:sitramix/services/remote/afiliaciones_api.dart';
import 'package:sitramix/services/remote/tarifas_api.dart';

import 'helpers/mock_api.dart';

void main() {
  group('TarifasApi', () {
    test('inactivar no envía cuerpo y devuelve activo == false', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'id': 4,
          'aportesGastosVarios': 12000,
          'fondoReposicion': 3000,
          'aporteSocialSocio': 2000,
          'total': 17000,
          'activo': false,
        }),
      );

      final tarifa = await TarifasApi(
        api: mock.createService(),
        token: 'jwt',
      ).inactivar(4);

      expect(mock.lastRequest.method, 'DELETE');
      expect(mock.lastRequest.url.path, ApiPaths.tarifa(4));
      expect(mock.lastRequest.body, isEmpty);
      expect(tarifa.id, 4);
      expect(tarifa.activo, isFalse);
      expect(tarifa.total, 17000.0);
    });

    test('crear omite id y total del cuerpo', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'id': 5,
          'total': 17000,
          'activo': true,
        }, status: 201),
      );

      const tarifa = Tarifa(
        aportesGastosVarios: 12000,
        fondoReposicion: 3000,
        aporteSocialSocio: 2000,
        activo: true,
      );
      await TarifasApi(api: mock.createService(), token: 'jwt').crear(tarifa);

      expect(mock.lastRequest.url.path, ApiPaths.tarifas);
      expect(mock.lastJsonBody.keys.toSet(), <String>{
        'aportesGastosVarios',
        'fondoReposicion',
        'aporteSocialSocio',
        'activo',
      });
    });

    test('listar envía page, pageSize y activo', () async {
      final mock = MockApi((_) => jsonResponse(const <dynamic>[]));

      await TarifasApi(
        api: mock.createService(),
        token: 'jwt',
      ).listar(query: const PageQuery(page: 1, pageSize: 100), activo: true);

      expect(mock.lastQuery, <String, String>{
        'page': '1',
        'pageSize': '100',
        'activo': 'true',
      });
    });
  });

  group('AfiliacionesApi', () {
    test('finalizar envía fechaFinAfiliacion en el DELETE', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'id': 12,
          'identificacionAsociado': '1099',
          'placaVehiculo': 'BRU001',
          'fechaAfiliacion': '2026-01-15',
          'fechaFinAfiliacion': '2026-10-31',
          'estado': 'FINALIZADA',
        }),
      );

      final afiliacion = await AfiliacionesApi(
        api: mock.createService(),
        token: 'jwt',
      ).finalizar(12, fechaFinAfiliacion: DateTime(2026, 10, 31));

      expect(mock.lastRequest.method, 'DELETE');
      expect(mock.lastRequest.url.path, ApiPaths.afiliacion(12));
      expect(mock.lastJsonBody, <String, dynamic>{
        'fechaFinAfiliacion': '2026-10-31',
      });
      expect(afiliacion.estado, EstadoAfiliacion.finalizada);
      expect(afiliacion.estaActiva, isFalse);
    });

    test(
      'finalizar sin fecha envía null para que el backend use hoy',
      () async {
        final mock = MockApi(
          (_) =>
              jsonResponse(<String, dynamic>{'id': 12, 'estado': 'FINALIZADA'}),
        );

        await AfiliacionesApi(
          api: mock.createService(),
          token: 'jwt',
        ).finalizar(12);

        expect(mock.lastJsonBody, <String, dynamic>{
          'fechaFinAfiliacion': null,
        });
      },
    );

    test('actualizar exige id antes de llamar a la API', () async {
      final mock = MockApi((_) => jsonResponse(<String, dynamic>{}));

      const afiliacion = Afiliacion(
        identificacionAsociado: '1099',
        placaVehiculo: 'BRU001',
        fechaAfiliacion: null,
      );

      await expectLater(
        AfiliacionesApi(
          api: mock.createService(),
          token: 'jwt',
        ).actualizar(afiliacion),
        throwsArgumentError,
      );
      expect(mock.requests, isEmpty);
    });

    test('listar combina paginación y filtros', () async {
      final mock = MockApi((_) => jsonResponse(const <dynamic>[]));

      await AfiliacionesApi(api: mock.createService(), token: 'jwt').listar(
        query: const PageQuery(page: 3, pageSize: 10),
        asociado: '1099',
        vehiculo: 'BRU001',
        estado: EstadoAfiliacion.activa,
      );

      expect(mock.lastRequest.url.path, ApiPaths.afiliaciones);
      expect(mock.lastQuery, <String, String>{
        'page': '3',
        'pageSize': '10',
        'asociado': '1099',
        'vehiculo': 'BRU001',
        'estado': 'ACTIVA',
      });
    });
  });
}
