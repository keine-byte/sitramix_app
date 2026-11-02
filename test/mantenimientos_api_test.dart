import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/mantenimiento/mantenimiento.dart';
import 'package:sitramix/services/remote/mantenimientos_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> mantenimientoJson({String estado = 'EN_MANTENIMIENTO'}) =>
    <String, dynamic>{
      'id': 5,
      'placaVehiculo': 'BRU001',
      'fechaIngreso': '2026-10-27T08:00:00-05:00',
      if (estado == 'FINALIZADO') 'fechaSalida': '2026-10-27T17:00:00-05:00',
      'motivo': 'Cambio de aceite',
      'estadoVehiculoIngreso': 'BUENO',
      'observaciones': 'Sin novedad',
      'estado': estado,
    };

void main() {
  group('MantenimientosApi', () {
    test('registrarIngreso envía la fecha ISO con offset', () async {
      final mock = MockApi(
        (_) => jsonResponse(mantenimientoJson(), status: 201),
      );

      final registro =
          await MantenimientosApi(
            api: mock.createService(),
            token: 'jwt',
          ).registrarIngreso(
            Mantenimiento(
              placaVehiculo: 'BRU001',
              fechaIngreso: DateTime(2026, 10, 27, 8),
              motivo: 'Cambio de aceite',
              estadoVehiculoIngreso: 'BUENO',
              observaciones: 'Sin novedad',
            ),
          );

      expect(mock.lastRequest.method, 'POST');
      expect(mock.lastRequest.url.path, ApiPaths.mantenimientos);
      expect(mock.lastJsonBody['placaVehiculo'], 'BRU001');
      expect(
        mock.lastJsonBody['fechaIngreso'],
        startsWith('2026-10-27T08:00:00'),
      );
      expect(
        mock.lastJsonBody['fechaIngreso'],
        matches(RegExp(r'[+-]\d{2}:\d{2}$')),
        reason: 'mantenimientos exige offset explícito',
      );
      expect(registro.estaAbierto, isTrue);
    });

    test('registrarSalida envía solo fechaSalida y observaciones', () async {
      final mock = MockApi(
        (_) => jsonResponse(mantenimientoJson(estado: 'FINALIZADO')),
      );

      final registro =
          await MantenimientosApi(
            api: mock.createService(),
            token: 'jwt',
          ).registrarSalida(
            5,
            fechaSalida: DateTime(2026, 10, 27, 17),
            observaciones: 'Aceite cambiado',
          );

      expect(mock.lastRequest.method, 'PUT');
      expect(mock.lastRequest.url.path, ApiPaths.mantenimiento(5));
      expect(mock.lastJsonBody.keys.toList(), <String>[
        'fechaSalida',
        'observaciones',
      ]);
      expect(
        mock.lastJsonBody['fechaSalida'],
        startsWith('2026-10-27T17:00:00'),
      );
      expect(registro.estaAbierto, isFalse);
      expect(registro.fechaSalida, isNotNull);
      expect(registro.estado, EstadoMantenimiento.finalizado);
    });

    test('listar filtra por placa y estado', () async {
      final mock = MockApi((_) => jsonResponse(const <dynamic>[]));

      await MantenimientosApi(
        api: mock.createService(),
        token: 'jwt',
      ).listar(placa: 'BRU001', estado: EstadoMantenimiento.enMantenimiento);

      expect(mock.lastRequest.url.path, ApiPaths.mantenimientos);
      expect(mock.lastQuery['placa'], 'BRU001');
      expect(mock.lastQuery['estado'], 'EN_MANTENIMIENTO');
      expect(mock.lastQuery['page'], '1');
    });

    test('mantenimientoSalidaBody expone las dos claves del cierre', () {
      final body = mantenimientoSalidaBody(
        fechaSalida: DateTime(2026, 10, 27, 17),
        observaciones: 'ok',
      );

      expect(body.keys.toSet(), <String>{'fechaSalida', 'observaciones'});
    });
  });
}
