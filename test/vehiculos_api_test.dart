import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/vehiculo/vehiculo.dart';
import 'package:sitramix/services/remote/vehiculos_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> vehiculoJson() => <String, dynamic>{
  'placa': 'BRU001',
  'tipo': 'BUS',
  'marca': 'Hino',
  'modelo': '2020',
  'capacidadPasajeros': 30,
  'tarjetaPropiedad': 'TP-0001',
  'activo': true,
  'tarifaId': 3,
  'tarifa': <String, dynamic>{'id': 3, 'total': 17000},
  'vigenciaSoat': '2027-01-31',
  'vigenciaTrm': '2027-01-31',
  'fechaIngreso': '2026-01-15',
};

void main() {
  group('VehiculosApi', () {
    test('consultar lee tarifa.id y tarifa.total anidados', () async {
      final mock = MockApi((_) => jsonResponse(vehiculoJson()));

      final vehiculo = await VehiculosApi(
        api: mock.createService(),
        token: 'jwt',
      ).consultar('BRU001');

      expect(mock.lastRequest.url.path, ApiPaths.vehiculo('BRU001'));
      expect(
        vehiculo.modelo,
        '2020',
        reason: 'la API envía el modelo como texto',
      );
      expect(vehiculo.tarifa, isNotNull);
      expect(vehiculo.tarifa!.id, 3);
      expect(vehiculo.tarifa!.total, 17000.0);
      expect(vehiculo.soatVencido, isFalse);
    });

    test('el PUT solo envía los seis campos editables', () async {
      final mock = MockApi((_) => jsonResponse(vehiculoJson()));

      const vehiculo = Vehiculo(
        placa: 'BRU001',
        tipo: 'BUS',
        marca: 'Hino',
        modelo: '2020',
        capacidadPasajeros: 30,
        tarjetaPropiedad: 'TP-0001',
        activo: true,
        tarifaId: 3,
        identificacionConductor: '1099',
      );

      await VehiculosApi(
        api: mock.createService(),
        token: 'jwt',
      ).actualizar(vehiculo);

      expect(mock.lastRequest.method, 'PUT');
      expect(mock.lastRequest.url.path, ApiPaths.vehiculo('BRU001'));
      expect(mock.lastJsonBody, <String, dynamic>{
        'identificacionConductor': '1099',
        'activo': true,
        'tarifaId': 3,
      });
      for (final campo in <String>['placa', 'tipo', 'marca', 'modelo']) {
        expect(
          mock.lastJsonBody.containsKey(campo),
          isFalse,
          reason: '$campo no es editable después del alta',
        );
      }
    });

    test('asignarConductor manda solo la identificación', () async {
      final mock = MockApi((_) => jsonResponse(vehiculoJson()));

      await VehiculosApi(
        api: mock.createService(),
        token: 'jwt',
      ).asignarConductor(placa: 'BRU001', identificacionConductor: '1099');

      expect(mock.lastJsonBody, <String, dynamic>{
        'identificacionConductor': '1099',
      });
    });

    test('crear envía los once campos del POST', () async {
      final mock = MockApi((_) => jsonResponse(vehiculoJson(), status: 201));

      await VehiculosApi(api: mock.createService(), token: 'jwt').crear(
        Vehiculo(
          placa: 'BRU001',
          tipo: 'BUS',
          marca: 'Hino',
          modelo: '2020',
          capacidadPasajeros: 30,
          tarjetaPropiedad: 'TP-0001',
          activo: true,
          tarifaId: 3,
          vigenciaSoat: DateTime(2027, 1, 31),
          vigenciaTrm: DateTime(2027, 1, 31),
          fechaIngreso: DateTime(2026, 1, 15),
        ),
      );

      expect(mock.lastJsonBody.keys.toSet(), <String>{
        'placa',
        'tipo',
        'marca',
        'modelo',
        'capacidadPasajeros',
        'tarjetaPropiedad',
        'activo',
        'tarifaId',
        'vigenciaSoat',
        'vigenciaTrm',
        'fechaIngreso',
      });
      expect(mock.lastJsonBody['vigenciaSoat'], '2027-01-31');
    });

    test('listar envía placa y tipo como filtros', () async {
      final mock = MockApi((_) => jsonResponse(const <dynamic>[]));

      await VehiculosApi(
        api: mock.createService(),
        token: 'jwt',
      ).listar(placa: 'BRU001', tipo: 'BUS');

      expect(mock.lastQuery['placa'], 'BRU001');
      expect(mock.lastQuery['tipo'], 'BUS');
    });
  });
}
