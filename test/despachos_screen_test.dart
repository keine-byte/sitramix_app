import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/screens/despachos_screen.dart';
import 'package:sitramix/services/remote/despachos_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> despachoJson({
  int? id = 1,
  String ruta = 'Sincelejo - Cartagena',
  String placa = 'BRU001',
  int pasajeros = 18,
  String estado = 'REGISTRADO',
  String? motivoCancelacion,
}) => <String, dynamic>{
  'id': id,
  'ruta': ruta,
  'placaVehiculo': placa,
  'numeroPasajeros': pasajeros,
  'fecha': '2026-10-26',
  'hora': '06:30:00',
  'estado': estado,
  'fechaRegistro': '2026-10-25T18:00:00-05:00',
  'registradoPor': 'asistente.bruno',
  'fechaCancelacion': motivoCancelacion == null
      ? null
      : '2026-10-26T07:00:00-05:00',
  'canceladoPor': motivoCancelacion == null ? null : 'gerente.ana',
  'motivoCancelacion': motivoCancelacion,
};

Widget appCon(MockApi mock, {Map<String, WidgetBuilder>? rutas}) => MaterialApp(
  routes: rutas ?? const <String, WidgetBuilder>{},
  home: DespachosScreen(
    api: DespachosApi(api: mock.createService(), token: 'jwt'),
  ),
);

Future<void> cargar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void pantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

MockApi backend() => MockApi((request) {
  if (request.method == 'POST') {
    return jsonResponse(despachoJson(id: 12), status: 201);
  }
  if (request.method == 'DELETE') {
    return jsonResponse(
      despachoJson(estado: 'CANCELADO', motivoCancelacion: 'Falla mecánica'),
    );
  }
  if (request.url.path == '/api/despachos/1') {
    return jsonResponse(despachoJson());
  }
  if (request.url.path == '/api/despachos/2') {
    return jsonResponse(
      despachoJson(
        id: 2,
        ruta: 'Sincelejo - Montería',
        placa: 'BRU002',
        estado: 'CANCELADO',
        motivoCancelacion: 'Falla mecánica',
      ),
    );
  }
  return jsonResponse(<dynamic>[
    despachoJson(),
    despachoJson(
      id: 2,
      ruta: 'Sincelejo - Montería',
      placa: 'BRU002',
      estado: 'CANCELADO',
      motivoCancelacion: 'Falla mecánica',
    ),
  ]);
});

void main() {
  testWidgets('lista los despachos con el token y de 20 en 20', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(mock.lastRequest.url.path, '/api/despachos');
    expect(mock.lastRequest.headers['authorization'], 'Bearer jwt');
    expect(mock.lastQuery['pageSize'], '20');
    expect(find.text('Despacho #1'), findsOneWidget);
    expect(find.text('Despacho #2'), findsOneWidget);
    expect(find.text('Sincelejo - Cartagena'), findsOneWidget);
    expect(find.text('Sincelejo - Montería'), findsOneWidget);
    expect(find.text('18 pasajeros'), findsNWidgets(2));
    expect(find.text('26/10/2026 · 06:30:00'), findsNWidgets(2));
    expect(find.text('REGISTRADO'), findsOneWidget);
    expect(find.text('CANCELADO'), findsOneWidget);
  });

  testWidgets('busca por vehículo, ruta y fecha', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

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

    expect(mock.lastQuery['vehiculo'], 'BRU001');
    expect(mock.lastQuery['ruta'], 'Cartagena');

    await tester.tap(find.text('Fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final hoy = DateTime.now();
    final mes = hoy.month.toString().padLeft(2, '0');
    expect(mock.lastQuery['fecha'], '${hoy.year}-$mes-01');

    await tester.tap(find.text('Quitar fecha'));
    await cargar(tester);
    expect(mock.lastQuery.containsKey('fecha'), isFalse);
  });

  testWidgets('al tocar la tarjeta consulta el detalle del despacho', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Despacho #1'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.url.path, '/api/despachos/1');
    expect(find.text('Ruta'), findsNWidgets(2));
    expect(find.text('Pasajeros'), findsOneWidget);
    expect(find.text('Hora'), findsOneWidget);
    expect(find.text('Registrado por'), findsOneWidget);
    expect(find.text('Motivo de cancelación'), findsOneWidget);
    expect(find.text('Cancelar despacho'), findsOneWidget);
  });

  testWidgets('sin motivo no cancela el despacho', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Despacho #1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cancelar despacho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar despacho'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe el motivo de la cancelación'), findsOneWidget);
    expect(mock.requests.any((request) => request.method == 'DELETE'), isFalse);
  });

  testWidgets('cancelar envía el DELETE con el motivo', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Despacho #1'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo de cancelación'),
      'Falla mecánica',
    );
    await tester.ensureVisible(find.text('Cancelar despacho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar despacho'));
    await tester.pumpAndSettle();

    expect(find.textContaining('quedará en CANCELADO'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar despacho'));
    await tester.pumpAndSettle();

    final borrado = mock.ultimaCon('DELETE');
    expect(borrado.url.path, '/api/despachos/1');
    expect(mock.jsonBody(borrado), <String, dynamic>{
      'motivo': 'Falla mecánica',
    });
    expect(find.text('El despacho ya está cancelado.'), findsOneWidget);
    expect(find.text('Cancelado por'), findsOneWidget);
    expect(find.text('Cancelar despacho'), findsNothing);
  });

  testWidgets('un despacho cancelado no ofrece cancelarlo otra vez', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Despacho #2'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.url.path, '/api/despachos/2');
    expect(find.text('El despacho ya está cancelado.'), findsOneWidget);
    expect(find.text('gerente.ana'), findsOneWidget);
    expect(find.text('Cancelar despacho'), findsNothing);
  });

  testWidgets('sin despachos muestra el estado vacío', (tester) async {
    final mock = MockApi((_) => jsonResponse(<dynamic>[]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Sin despachos'), findsOneWidget);
    expect(find.text('No hay despachos para estos filtros.'), findsOneWidget);
  });

  testWidgets('un 401 limpia la sesión y vuelve al login', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'detail': 'Token expirado.',
      }, status: 401),
    );

    await tester.pumpWidget(
      appCon(
        mock,
        rutas: <String, WidgetBuilder>{
          '/login': (_) => const Scaffold(body: Text('Pantalla de login')),
        },
      ),
    );
    await cargar(tester);
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de login'), findsOneWidget);
    expect(
      find.text('Tu sesión expiró. Vuelve a iniciar sesión.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('el AppBar abre el alta y refresca al guardar', (tester) async {
    pantallaAlta(tester);
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.byTooltip('Nuevo despacho'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo despacho'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ruta'),
      'Sincelejo - Cartagena',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vehículo'),
      'bru002',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Número de pasajeros'),
      '24',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar despacho'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/despachos');
    expect(mock.jsonBody(post), <String, dynamic>{
      'ruta': 'Sincelejo - Cartagena',
      'placaVehiculo': 'BRU002',
      'numeroPasajeros': 24,
    });

    expect(find.text('Despacho #12 registrado.'), findsOneWidget);
    expect(mock.lastRequest.method, 'GET');
    expect(find.text('Nuevo despacho'), findsNothing);
  });

  testWidgets('un error del backend se muestra tal cual', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Forbidden',
        'detail': 'No tienes permisos para ver despachos.',
      }, status: 403),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('No se pudieron cargar los despachos'), findsOneWidget);
    expect(find.text('No tienes permisos para ver despachos.'), findsOneWidget);
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

    expect(find.text('Despacho #1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
