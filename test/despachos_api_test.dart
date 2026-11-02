import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/despacho/despacho.dart';
import 'package:sitramix/services/remote/despachos_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> despachoJson({String estado = 'REGISTRADO'}) =>
    <String, dynamic>{
      'id': 7,
      'ruta': 'Ruta 1',
      'placaVehiculo': 'BRU001',
      'numeroPasajeros': 20,
      'fecha': '2026-10-27',
      'hora': '08:30:00',
      'estado': estado,
      'registradoPor': 'aperez',
      if (estado == 'CANCELADO') ...<String, dynamic>{
        'fechaCancelacion': '2026-10-27T09:00:00-05:00',
        'canceladoPor': 'jefe',
        'motivoCancelacion': 'Clima adverso',
      },
    };

void main() {
  group('DespachosApi', () {
    test('crear separa fecha y hora y devuelve REGISTRADO', () async {
      final mock = MockApi((_) => jsonResponse(despachoJson(), status: 201));

      final despacho =
          await DespachosApi(api: mock.createService(), token: 'jwt').crear(
            Despacho(
              ruta: 'Ruta 1',
              placaVehiculo: 'BRU001',
              numeroPasajeros: 20,
              fecha: DateTime(2026, 10, 27),
              hora: '08:30:00',
            ),
          );

      expect(mock.lastRequest.method, 'POST');
      expect(mock.lastRequest.url.path, ApiPaths.despachos);
      expect(mock.lastJsonBody['fecha'], '2026-10-27');
      expect(mock.lastJsonBody['hora'], '08:30:00');
      expect(mock.lastJsonBody['numeroPasajeros'], 20);
      expect(despacho.estado, EstadoDespacho.registrado);
      expect(despacho.estaCancelado, isFalse);
    });

    test('cancelar envía el motivo en el cuerpo del DELETE', () async {
      final mock = MockApi(
        (_) => jsonResponse(despachoJson(estado: 'CANCELADO')),
      );

      final despacho = await DespachosApi(
        api: mock.createService(),
        token: 'jwt',
      ).cancelar(7, motivo: 'Clima adverso');

      expect(mock.lastRequest.method, 'DELETE');
      expect(mock.lastRequest.url.path, ApiPaths.despacho(7));
      expect(mock.lastJsonBody, <String, dynamic>{'motivo': 'Clima adverso'});
      expect(despacho.estado, EstadoDespacho.cancelado);
      expect(despacho.estaCancelado, isTrue);
      expect(despacho.motivoCancelacion, 'Clima adverso');
      expect(despacho.canceladoPor, 'jefe');
    });

    test('listar filtra por fecha, vehículo y ruta', () async {
      final mock = MockApi((_) => jsonResponse(const <dynamic>[]));

      await DespachosApi(api: mock.createService(), token: 'jwt').listar(
        fecha: DateTime(2026, 10, 27),
        vehiculo: 'BRU001',
        ruta: 'Ruta 1',
      );

      expect(mock.lastQuery['fecha'], '2026-10-27');
      expect(mock.lastQuery['vehiculo'], 'BRU001');
      expect(mock.lastQuery['ruta'], 'Ruta 1');
      expect(mock.lastQuery['page'], '1');
    });
  });
}
