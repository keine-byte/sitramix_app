import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/screens/mantenimientos_screen.dart';
import 'package:sitramix/services/remote/mantenimientos_api.dart';
import 'package:sitramix/utils/fechas.dart';

import 'helpers/mock_api.dart';

const String ingreso = '2026-10-27T08:00:00-05:00';

Map<String, dynamic> mantenimientoJson({
  int? id = 1,
  String placa = 'BRU001',
  String estado = 'EN_MANTENIMIENTO',
  String? fechaSalida,
}) => <String, dynamic>{
  'id': id,
  'placaVehiculo': placa,
  'fechaIngreso': ingreso,
  'fechaSalida': fechaSalida,
  'motivo': 'Revisión de frenos',
  'estadoVehiculoIngreso': 'Ruido al frenar',
  'observaciones': 'Ingreso al taller',
  'estado': estado,
};

Widget appCon(MockApi mock) => MaterialApp(
  home: MantenimientosScreen(
    api: MantenimientosApi(api: mock.createService(), token: 'jwt'),
  ),
);

Future<void> cargar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

MockApi backend() => MockApi((request) {
  if (request.method == 'PUT') {
    return jsonResponse(
      mantenimientoJson(estado: 'FINALIZADO', fechaSalida: '2026-10-28'),
    );
  }
  if (request.url.path == '/api/mantenimientos/1') {
    return jsonResponse(mantenimientoJson());
  }
  if (request.url.path == '/api/mantenimientos/2') {
    return jsonResponse(
      mantenimientoJson(
        id: 2,
        placa: 'BRU002',
        estado: 'FINALIZADO',
        fechaSalida: '2026-10-28T17:00:00-05:00',
      ),
    );
  }
  return jsonResponse(<dynamic>[
    mantenimientoJson(),
    mantenimientoJson(
      id: 2,
      placa: 'BRU002',
      estado: 'FINALIZADO',
      fechaSalida: '2026-10-28T17:00:00-05:00',
    ),
  ]);
});

void main() {
  testWidgets('lista los mantenimientos con el token y de 20 en 20', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(mock.lastRequest.url.path, '/api/mantenimientos');
    expect(mock.lastRequest.headers['authorization'], 'Bearer jwt');
    expect(mock.lastQuery['pageSize'], '20');
    expect(find.text('Mantenimiento #1'), findsOneWidget);
    expect(find.text('Mantenimiento #2'), findsOneWidget);
    expect(find.text('EN_MANTENIMIENTO'), findsOneWidget);
    expect(find.text('FINALIZADO'), findsOneWidget);
    expect(find.text('BRU001'), findsOneWidget);
    expect(find.text('Revisión de frenos'), findsNWidgets(2));
    expect(
      find.text('Ingreso ${formatearFecha(DateTime.parse(ingreso))}'),
      findsNWidgets(2),
    );
  });

  testWidgets('filtra por placa y por estado', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vehículo'),
      'BRU001',
    );
    await tester.tap(find.text('Buscar'));
    await cargar(tester);
    expect(mock.lastQuery['placa'], 'BRU001');

    await tester.tap(find.text('Finalizados'));
    await cargar(tester);
    expect(mock.lastQuery['estado'], 'FINALIZADO');

    await tester.tap(find.text('Todos'));
    await cargar(tester);
    expect(mock.lastQuery.containsKey('estado'), isFalse);
  });

  testWidgets('el rango de ingreso se envía en ISO con offset', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Desde'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final hoy = DateTime.now();
    final mes = hoy.month.toString().padLeft(2, '0');
    final desde = mock.lastQuery['desde'] ?? '';
    expect(desde, startsWith('${hoy.year}-$mes-01T'));
    expect(desde, contains(':'));

    await tester.tap(find.text('Quitar fechas'));
    await cargar(tester);
    expect(mock.lastQuery.containsKey('desde'), isFalse);
  });

  testWidgets('al tocar la tarjeta consulta el detalle', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Mantenimiento #1'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.url.path, '/api/mantenimientos/1');
    expect(find.text('Fecha de ingreso'), findsOneWidget);
    expect(find.text('Fecha de salida'), findsOneWidget);
    expect(find.text('Sin salida'), findsOneWidget);
    expect(find.text('Estado al ingreso'), findsOneWidget);
    expect(find.text('Ruido al frenar'), findsOneWidget);
    expect(find.text('Observaciones'), findsOneWidget);
    expect(find.text('Registrar salida'), findsOneWidget);
  });

  testWidgets('sin observaciones no registra la salida', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Mantenimiento #1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Registrar salida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar salida'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe las observaciones de la salida'), findsOneWidget);
    expect(mock.requests.any((request) => request.method == 'PUT'), isFalse);
  });

  testWidgets('registrar la salida envía el PUT y cierra el mantenimiento', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Mantenimiento #1'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Observaciones de la salida'),
      'Cambio de pastillas',
    );
    await tester.ensureVisible(find.text('Registrar salida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar salida'));
    await tester.pumpAndSettle();

    expect(find.text('Salida del taller'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Registrar'));
    await tester.pumpAndSettle();

    final salida = mock.ultimaCon('PUT');
    expect(salida.url.path, '/api/mantenimientos/1');
    final body = mock.jsonBody(salida);
    expect(body['observaciones'], 'Cambio de pastillas');
    expect(
      body['fechaSalida'],
      matches(
        RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?[+-]\d{2}:\d{2}$'),
      ),
    );
    expect(find.text('El vehículo ya salió del taller.'), findsOneWidget);
    expect(find.text('Registrar salida'), findsNothing);
  });

  testWidgets('un mantenimiento finalizado no ofrece registrar salida', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Mantenimiento #2'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.url.path, '/api/mantenimientos/2');
    expect(find.text('El vehículo ya salió del taller.'), findsOneWidget);
    expect(find.text('Registrar salida'), findsNothing);
  });

  testWidgets('un error del backend se muestra tal cual', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Forbidden',
        'detail': 'No tienes permisos para ver mantenimientos.',
      }, status: 403),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(
      find.text('No se pudieron cargar los mantenimientos'),
      findsOneWidget,
    );
    expect(
      find.text('No tienes permisos para ver mantenimientos.'),
      findsOneWidget,
    );
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

    expect(find.text('Mantenimiento #1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
