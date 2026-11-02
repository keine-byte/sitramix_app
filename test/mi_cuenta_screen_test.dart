import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/screens/mi_cuenta_screen.dart';
import 'package:sitramix/services/remote/mi_cuenta_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> vehiculoJson({
  String placa = 'BRU001',
  String tipo = 'BUS',
  String marca = 'Hino',
  String modelo = '2020',
  int capacidad = 30,
  String tarjeta = 'TP-0001',
  bool activo = true,
  Map<String, dynamic>? tarifa = const <String, dynamic>{
    'id': 2,
    'total': 17000,
  },
  String soat = '2020-05-31',
  String trm = '2026-12-31',
}) => <String, dynamic>{
  'placa': placa,
  'tipo': tipo,
  'marca': marca,
  'modelo': modelo,
  'capacidadPasajeros': capacidad,
  'tarjetaPropiedad': tarjeta,
  'activo': activo,
  'tarifa': tarifa,
  'vigenciaSoat': soat,
  'vigenciaTrm': trm,
  'fechaIngreso': '2024-02-01',
};

Map<String, dynamic> viajeJson({
  int numero = 15,
  String fecha = '2026-10-20',
  String hora = '06:30:00',
  String placa = 'BRU001',
  String estado = 'ACTIVA',
  String estadoPago = 'PENDIENTE',
  double valor = 17000,
}) => <String, dynamic>{
  'numero': numero,
  'fecha': fecha,
  'hora': hora,
  'placaVehiculo': placa,
  'tipo': 'VIAJE',
  'estado': estado,
  'tarifaId': 2,
  'valorPagado': valor,
  'estadoPago': estadoPago,
  'conductor': <String, dynamic>{
    'Identificacion': '123',
    'Nombre del conductor': 'Ana Pérez',
  },
};

Map<String, dynamic> despachoJson({
  int id = 7,
  String ruta = 'Sincelejo - Cartagena',
  String placa = 'BRU001',
  int pasajeros = 18,
  String estado = 'REGISTRADO',
  String? motivo,
}) => <String, dynamic>{
  'id': id,
  'ruta': ruta,
  'placaVehiculo': placa,
  'numeroPasajeros': pasajeros,
  'fecha': '2026-10-25',
  'hora': '06:30:00',
  'estado': estado,
  'fechaRegistro': '2026-10-24T18:00:00-05:00',
  'registradoPor': 'asistente.bruno',
  'fechaCancelacion': motivo == null ? null : '2026-10-25T07:00:00-05:00',
  'canceladoPor': motivo == null ? null : 'gerente.ana',
  'motivoCancelacion': motivo,
};

Widget appCon(MockApi mock) => MaterialApp(
  home: MiCuentaScreen(
    api: MiCuentaApi(api: mock.createService(), token: 'jwt-asociado'),
  ),
);

Future<void> cargar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

MockApi backend() => MockApi((request) {
  if (request.url.path == '/api/mi-cuenta/viajes') {
    return jsonResponse(<dynamic>[
      viajeJson(),
      viajeJson(
        numero: 16,
        fecha: '2026-10-21',
        hora: '07:00:00',
        placa: 'BRU002',
        estado: 'ANULADA',
        estadoPago: 'PAGADA',
        valor: 0,
      ),
    ]);
  }
  if (request.url.path == '/api/mi-cuenta/despachos') {
    return jsonResponse(<dynamic>[
      despachoJson(),
      despachoJson(
        id: 8,
        ruta: 'Sincelejo - Montería',
        placa: 'BRU002',
        estado: 'CANCELADO',
        motivo: 'Falla mecánica',
      ),
    ]);
  }
  return jsonResponse(<dynamic>[
    vehiculoJson(),
    vehiculoJson(
      placa: 'BRU002',
      tipo: 'MICROBUS',
      marca: 'Toyota',
      modelo: '2019',
      capacidad: 20,
      tarjeta: 'TP-0002',
      activo: false,
      tarifa: null,
      soat: '2026-12-31',
    ),
  ]);
});

String primeroDelMes() {
  final hoy = DateTime.now();
  final mes = hoy.month.toString().padLeft(2, '0');
  return '${hoy.year}-$mes-01';
}

void main() {
  testWidgets('abre en Vehículos con el token del asociado y sin paginar', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(mock.lastRequest.method, 'GET');
    expect(mock.lastRequest.url.path, '/api/mi-cuenta/vehiculos');
    expect(mock.lastRequest.headers['authorization'], 'Bearer jwt-asociado');
    expect(mock.lastQuery, isEmpty);
    expect(find.text('BRU001'), findsOneWidget);
    expect(find.text('BRU002'), findsOneWidget);
    expect(find.text('Hino 2020 · 30 pasajeros'), findsOneWidget);
    expect(find.text('Toyota 2019 · 20 pasajeros'), findsOneWidget);
    expect(find.text('Tarifa \$ 17.000'), findsOneWidget);
    expect(find.text('Tarifa sin asignar'), findsOneWidget);
    expect(find.text('SOAT 31/05/2020 · TRM 31/12/2026'), findsOneWidget);
    expect(find.text('SOAT VENCIDO'), findsOneWidget);
    expect(find.text('INACTIVO'), findsOneWidget);
    expect(
      find.text('Estos son los vehículos afiliados a tu cuenta.'),
      findsOneWidget,
    );
  });

  testWidgets('el detalle del vehículo usa los datos del listado', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    final antes = mock.requests.length;
    await tester.tap(find.text('BRU002'));
    await tester.pumpAndSettle();

    expect(mock.requests.length, antes);
    expect(find.text('Marca'), findsOneWidget);
    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('Tarjeta de propiedad'), findsOneWidget);
    expect(find.text('TP-0002'), findsOneWidget);
    expect(find.text('Inactivo'), findsOneWidget);
    expect(find.text('Sin tarifa asignada'), findsOneWidget);
    expect(find.text('Capacidad'), findsOneWidget);
  });

  testWidgets('Viajes filtra por placa y por rango de fechas', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Viajes'));
    await cargar(tester);

    expect(mock.lastRequest.url.path, '/api/mi-cuenta/viajes');
    expect(mock.lastQuery['page'], '1');
    expect(mock.lastQuery['pageSize'], '20');
    expect(find.text('Planilla #15'), findsOneWidget);
    expect(find.text('Planilla #16'), findsOneWidget);
    expect(find.text('20/10/2026 · 06:30:00'), findsOneWidget);
    expect(find.text('Pagado \$ 17.000'), findsOneWidget);
    expect(find.text('PENDIENTE'), findsOneWidget);
    expect(find.text('PAGADA'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vehículo'),
      'BRU002',
    );
    await tester.tap(find.text('Buscar'));
    await cargar(tester);

    expect(mock.lastQuery['placa'], 'BRU002');

    await tester.tap(find.text('Desde'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(mock.lastQuery['desde'], primeroDelMes());
    expect(mock.lastQuery.containsKey('hasta'), isFalse);

    await tester.tap(find.text('Quitar fechas'));
    await cargar(tester);

    expect(mock.lastQuery.containsKey('desde'), isFalse);
    expect(find.text('Quitar fechas'), findsNothing);
  });

  testWidgets('Despachos añade el filtro por ruta', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Despachos'));
    await cargar(tester);

    expect(mock.lastRequest.url.path, '/api/mi-cuenta/despachos');
    expect(find.text('Despacho #7'), findsOneWidget);
    expect(find.text('Despacho #8'), findsOneWidget);
    expect(find.text('18 pasajeros'), findsNWidgets(2));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vehículo'),
      'BRU001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ruta'),
      'Cartagena',
    );
    await tester.tap(find.text('Buscar'));
    await cargar(tester);

    expect(mock.lastQuery['placa'], 'BRU001');
    expect(mock.lastQuery['ruta'], 'Cartagena');
  });

  testWidgets('el detalle del viaje muestra al conductor', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);
    await tester.tap(find.text('Viajes'));
    await cargar(tester);

    await tester.tap(find.text('Planilla #15'));
    await tester.pumpAndSettle();

    expect(find.text('Conductor'), findsOneWidget);
    expect(find.text('Ana Pérez · 123'), findsOneWidget);
    expect(find.text('Estado de pago'), findsOneWidget);
    expect(find.text('Valor pagado'), findsOneWidget);
    expect(find.text('ID 2'), findsOneWidget);
  });

  testWidgets('el detalle del despacho es solo lectura', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);
    await tester.tap(find.text('Despachos'));
    await cargar(tester);

    await tester.tap(find.text('Despacho #8'));
    await tester.pumpAndSettle();

    expect(find.text('Registrado por'), findsOneWidget);
    expect(find.text('Cancelado por'), findsOneWidget);
    expect(find.text('Falla mecánica'), findsOneWidget);
    expect(find.text('Cancelar despacho'), findsNothing);
  });

  testWidgets('sin vehículos muestra el estado vacío', (tester) async {
    final mock = MockApi((_) => jsonResponse(<dynamic>[]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Sin vehículos'), findsOneWidget);
    expect(
      find.text('No tienes vehículos afiliados a tu cuenta.'),
      findsOneWidget,
    );
  });

  testWidgets('un error del token de asociado se muestra tal cual', (
    tester,
  ) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Unauthorized',
        'detail': 'El token del asociado expiró.',
      }, status: 401),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('No se pudo cargar Mi cuenta'), findsOneWidget);
    expect(find.text('El token del asociado expiró.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('no desborda en una pantalla de 320x640', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('BRU001'), findsOneWidget);

    await tester.tap(find.text('Despachos'));
    await cargar(tester);

    expect(find.text('Despacho #7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
