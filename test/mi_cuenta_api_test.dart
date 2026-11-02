import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/services/remote/mi_cuenta_api.dart';

import 'helpers/mock_api.dart';

void main() {
  group('MiCuentaApi', () {
    test('vehiculos usa el token del asociado y no pagina', () async {
      final mock = MockApi(
        (_) => jsonResponse(<dynamic>[
          <String, dynamic>{
            'placa': 'BRU001',
            'tipo': 'BUS',
            'marca': 'Hino',
            'modelo': '2020',
            'capacidadPasajeros': 30,
            'tarjetaPropiedad': 'TP-0001',
            'activo': true,
          },
        ]),
      );

      final vehiculos = await MiCuentaApi(
        api: mock.createService(),
        token: 'jwt-asociado',
      ).vehiculos();

      expect(mock.lastRequest.method, 'GET');
      expect(mock.lastRequest.url.path, ApiPaths.miCuentaVehiculos);
      expect(mock.lastRequest.url.queryParameters, isEmpty);
      expect(mock.lastRequest.headers['authorization'], 'Bearer jwt-asociado');
      expect(vehiculos.single.placa, 'BRU001');
    });

    test('viajes filtra por rango de fechas y placa', () async {
      final mock = MockApi((_) => jsonResponse(const <dynamic>[]));

      await MiCuentaApi(
        api: mock.createService(),
        token: 'jwt-asociado',
      ).viajes(
        query: const PageQuery(page: 1, pageSize: 10),
        desde: DateTime(2026, 10, 1),
        hasta: DateTime(2026, 10, 31),
        placa: 'BRU001',
      );

      expect(mock.lastRequest.url.path, ApiPaths.miCuentaViajes);
      expect(mock.lastQuery, <String, String>{
        'page': '1',
        'pageSize': '10',
        'desde': '2026-10-01',
        'hasta': '2026-10-31',
        'placa': 'BRU001',
      });
    });

    test('despachos filtra por ruta además de las fechas', () async {
      final mock = MockApi((_) => jsonResponse(const <dynamic>[]));

      await MiCuentaApi(
        api: mock.createService(),
        token: 'jwt-asociado',
      ).despachos(desde: DateTime(2026, 10, 1), ruta: 'Ruta 1');

      expect(mock.lastRequest.url.path, ApiPaths.miCuentaDespachos);
      expect(mock.lastQuery['desde'], '2026-10-01');
      expect(mock.lastQuery['ruta'], 'Ruta 1');
      expect(mock.lastQuery.containsKey('hasta'), isFalse);
    });
  });
}
