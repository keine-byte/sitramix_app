import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/planilla/planilla.dart';
import 'package:sitramix/services/remote/planillas_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> planillaJson({
  int numero = 25,
  String estado = 'ACTIVA',
  String estadoPago = 'PENDIENTE',
}) => <String, dynamic>{
  'numero': numero,
  'fecha': '2026-10-27',
  'hora': '08:30:00',
  'placaVehiculo': 'BRU001',
  'tipo': 'VIAJE',
  'estado': estado,
  'tarifaId': 3,
  'valorPagado': 17000,
  'estadoPago': estadoPago,
  'conductor': <String, dynamic>{
    'Identificacion': '1099999',
    'Nombre del conductor': 'Ana Perez',
  },
};

void main() {
  group('PlanillasApi', () {
    test('listar envía paginación, fecha, vehículo y estado', () async {
      final mock = MockApi((_) => jsonResponse(<dynamic>[planillaJson()]));

      final planillas =
          await PlanillasApi(api: mock.createService(), token: 'jwt').listar(
            query: const PageQuery(page: 2, pageSize: 25),
            fecha: DateTime(2026, 10, 27),
            vehiculo: 'BRU001',
            estado: EstadoPlanilla.activa,
          );

      expect(mock.lastRequest.url.path, ApiPaths.planillas);
      expect(mock.lastRequest.headers['authorization'], 'Bearer jwt');
      expect(mock.lastQuery, <String, String>{
        'page': '2',
        'pageSize': '25',
        'fecha': '2026-10-27',
        'vehiculo': 'BRU001',
        'estado': 'ACTIVA',
      });
      expect(planillas, hasLength(1));
      expect(planillas.single.numero, 25);
    });

    test('fromJson lee las claves con espacio del conductor', () {
      final planilla = Planilla.fromJson(planillaJson());

      expect(planilla.hora, '08:30:00');
      expect(planilla.fecha, DateTime(2026, 10, 27));
      expect(planilla.conductor, isNotNull);
      expect(planilla.conductor!.identificacion, '1099999');
      expect(planilla.conductor!.nombre, 'Ana Perez');
      expect(planilla.estaPagada, isFalse);
      expect(planilla.estado, EstadoPlanilla.activa);
      expect(planilla.valorPagado, 17000.0);
    });

    test('fromJson tolera una planilla sin conductor', () {
      final planilla = Planilla.fromJson(<String, dynamic>{
        'numero': 26,
        'conductor': null,
      });

      expect(planilla.conductor, isNull);
      expect(planilla.estado, EstadoPlanilla.desconocido);
      expect(planilla.estadoPago, EstadoPago.desconocido);
    });

    test('masivas devuelve el informe y respeta la invariante', () async {
      final mock = MockApi(
        (_) => jsonResponse(<String, dynamic>{
          'totalSolicitadas': 3,
          'totalRegistradas': 2,
          'totalRechazadas': 1,
          'correctas': <dynamic>[
            planillaJson(numero: 30),
            planillaJson(numero: 31),
          ],
          'rechazadas': <dynamic>[
            <String, dynamic>{
              'placaVehiculo': 'XYZ999',
              'codigo': 409,
              'motivo': 'El vehiculo ya tiene planilla para esa fecha.',
            },
          ],
        }),
      );

      final informe =
          await PlanillasApi(
            api: mock.createService(),
            token: 'jwt',
          ).crearMasivas(
            PlanillaMasivaRequest(
              fecha: DateTime(2026, 10, 27),
              placasVehiculos: const <String>['BRU001', 'BRU002', 'XYZ999'],
              tipo: 'VIAJE',
              tarifaId: 3,
            ),
          );

      expect(mock.lastRequest.url.path, ApiPaths.planillasMasivas);
      expect(mock.lastJsonBody['fecha'], '2026-10-27');
      expect(mock.lastJsonBody['placasVehiculos'], <String>[
        'BRU001',
        'BRU002',
        'XYZ999',
      ]);
      expect(informe.totalSolicitadas, 3);
      expect(informe.correctas, hasLength(2));
      expect(informe.rechazadas.single.codigo, 409);
      expect(
        informe.esCoherente,
        isTrue,
        reason: 'totalSolicitadas == registradas + rechazadas',
      );
    });

    test('anular no envía cuerpo y devuelve la planilla ANULADA', () async {
      final mock = MockApi(
        (_) => jsonResponse(planillaJson(estado: 'ANULADA')),
      );

      final planilla = await PlanillasApi(
        api: mock.createService(),
        token: 'jwt',
      ).anular(25);

      expect(mock.lastRequest.method, 'DELETE');
      expect(mock.lastRequest.url.path, ApiPaths.planilla(25));
      expect(mock.lastRequest.body, isEmpty);
      expect(planilla.estado, EstadoPlanilla.anulada);
    });

    test('crear envía solo los campos del POST', () async {
      final mock = MockApi((_) => jsonResponse(planillaJson(), status: 201));

      await PlanillasApi(api: mock.createService(), token: 'jwt').crear(
        Planilla(
          fecha: DateTime(2026, 10, 27),
          placaVehiculo: 'BRU001',
          tipo: 'VIAJE',
          tarifaId: 3,
        ),
      );

      expect(mock.lastJsonBody, <String, dynamic>{
        'fecha': '2026-10-27',
        'placaVehiculo': 'BRU001',
        'tipo': 'VIAJE',
        'estado': 'ACTIVA',
        'tarifaId': 3,
      });
    });
  });
}
