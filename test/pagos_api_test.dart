import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/pago/pago.dart';
import 'package:sitramix/services/remote/api_service.dart';
import 'package:sitramix/services/remote/pagos_api.dart';

import 'helpers/mock_api.dart';

void main() {
  group('PagosApi', () {
    test('registrar no envía valorPagado: lo calcula el backend', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'id': 9,
          'numeroPlanilla': 25,
          'valorPagado': 17000,
          'fechaPago': '2026-10-27',
          'registradoPor': 'aperez',
          'fechaRegistro': '2026-10-27T09:15:00-05:00',
        }, status: 201),
      );

      final pago = await PagosApi(
        api: mock.createService(),
        token: 'jwt',
      ).registrar(Pago(numeroPlanilla: 25, fechaPago: DateTime(2026, 10, 27)));

      expect(mock.lastRequest.method, 'POST');
      expect(mock.lastRequest.url.path, ApiPaths.pagos);
      expect(mock.lastJsonBody, <String, dynamic>{
        'numeroPlanilla': 25,
        'fechaPago': '2026-10-27',
      });
      expect(mock.lastJsonBody.containsKey('valorPagado'), isFalse);
      expect(pago.valorPagado, 17000.0);
      expect(pago.registradoPor, 'aperez');
    });

    test(
      'el 409 por planilla duplicada conserva el mensaje del backend',
      () async {
        final mock = MockApi(
          (_) => jsonResponse(<String, dynamic>{
            'mensaje': 'La planilla ya tiene un pago registrado.',
          }, status: 409),
        );

        await expectLater(
          PagosApi(
            api: mock.createService(),
            token: 'jwt',
          ).registrar(const Pago(numeroPlanilla: 25)),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having(
                  (e) => e.message,
                  'message',
                  contains('ya tiene un pago registrado'),
                ),
          ),
        );
      },
    );

    test('listar combina planilla, placa y rango de fechas', () async {
      final mock = MockApi((_) => jsonResponse(const <dynamic>[]));

      await PagosApi(api: mock.createService(), token: 'jwt').listar(
        query: const PageQuery(page: 2, pageSize: 20),
        numeroPlanilla: 25,
        placa: 'BRU001',
        desde: DateTime(2026, 10, 1),
        hasta: DateTime(2026, 10, 31),
      );

      expect(mock.lastRequest.url.path, ApiPaths.pagos);
      expect(mock.lastQuery, <String, String>{
        'page': '2',
        'pageSize': '20',
        'numeroPlanilla': '25',
        'placa': 'BRU001',
        'desde': '2026-10-01',
        'hasta': '2026-10-31',
      });
    });
  });
}
