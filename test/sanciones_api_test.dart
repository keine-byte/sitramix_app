import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/sancion/sancion.dart';
import 'package:sitramix/services/remote/sanciones_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> sancionJson() => <String, dynamic>{
  'id': 3,
  'identificacionConductor': '1099999',
  'nombresConductor': 'Ana Perez',
  'motivo': 'Exceso de velocidad',
  'fechaInicio': '2026-10-01',
  'fechaFin': '2026-10-10',
  'fechaRegistro': '2026-09-30T16:00:00-05:00',
  'estado': 'ACTIVA',
};

void main() {
  group('SancionesApi', () {
    test('crear envía conductor, motivo y rango de fechas', () async {
      final mock = MockApi((_) => jsonResponse(sancionJson(), status: 201));

      final sancion =
          await SancionesApi(api: mock.createService(), token: 'jwt').crear(
            Sancion(
              identificacionConductor: '1099999',
              motivo: 'Exceso de velocidad',
              fechaInicio: DateTime(2026, 10, 1),
              fechaFin: DateTime(2026, 10, 10),
            ),
          );

      expect(mock.lastRequest.url.path, ApiPaths.sanciones);
      expect(mock.lastJsonBody, <String, dynamic>{
        'identificacionConductor': '1099999',
        'motivo': 'Exceso de velocidad',
        'fechaInicio': '2026-10-01',
        'fechaFin': '2026-10-10',
      });
      expect(sancion.estado, EstadoSancion.activa);
      expect(sancion.nombresConductor, 'Ana Perez');
    });

    test('actualizar manda el estado y no la identificación', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          ...sancionJson(),
          'estado': 'CUMPLIDA',
        }),
      );

      final sancion =
          await SancionesApi(
            api: mock.createService(),
            token: 'jwt',
          ).actualizar(
            Sancion(
              id: 3,
              identificacionConductor: '1099999',
              motivo: 'Exceso de velocidad',
              fechaInicio: DateTime(2026, 10, 1),
              fechaFin: DateTime(2026, 10, 10),
              estado: EstadoSancion.cumplida,
            ),
          );

      expect(mock.lastRequest.method, 'PUT');
      expect(mock.lastRequest.url.path, ApiPaths.sancion(3));
      expect(mock.lastJsonBody['estado'], 'CUMPLIDA');
      expect(
        mock.lastJsonBody.containsKey('identificacionConductor'),
        isFalse,
        reason: 'el conductor no se cambia en el PUT',
      );
      expect(sancion.estado, EstadoSancion.cumplida);
    });

    test('actualizar sin id falla antes de llamar a la API', () async {
      final mock = MockApi((_) => jsonResponse(<String, dynamic>{}));

      await expectLater(
        SancionesApi(api: mock.createService(), token: 'jwt').actualizar(
          const Sancion(identificacionConductor: '1099999', motivo: 'Sin id'),
        ),
        throwsArgumentError,
      );
      expect(mock.requests, isEmpty);
    });

    test('cubre() incluye los extremos del intervalo', () {
      final sancion = Sancion(
        identificacionConductor: '1099999',
        motivo: 'Exceso de velocidad',
        fechaInicio: DateTime(2026, 10, 1),
        fechaFin: DateTime(2026, 10, 10),
      );

      expect(sancion.cubre(DateTime(2026, 10, 1, 23, 59)), isTrue);
      expect(sancion.cubre(DateTime(2026, 10, 10)), isTrue);
      expect(sancion.cubre(DateTime(2026, 10, 11)), isFalse);
      expect(sancion.cubre(DateTime(2026, 9, 30)), isFalse);
    });

    test('listar envía el conductor y el estado', () async {
      final mock = MockApi((_) => jsonResponse(const <dynamic>[]));

      await SancionesApi(
        api: mock.createService(),
        token: 'jwt',
      ).listar(conductor: '1099999', estado: EstadoSancion.activa);

      expect(mock.lastQuery['conductor'], '1099999');
      expect(mock.lastQuery['estado'], 'ACTIVA');
    });
  });
}
