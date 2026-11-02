import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/screens/vehiculos_screen.dart';
import 'package:sitramix/services/remote/vehiculos_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> vehiculoJson({
  String placa = 'BRU001',
  String tipo = 'BUSETA',
  bool activo = true,
  String? vigenciaSoat = '2030-12-31',
  String? identificacionConductor,
}) {
  final json = <String, dynamic>{
    'placa': placa,
    'tipo': tipo,
    'marca': 'Chevrolet',
    'modelo': '2025',
    'capacidadPasajeros': 10,
    'tarjetaPropiedad': 'TP-BRU001',
    'activo': activo,
    'vigenciaSoat': vigenciaSoat,
    'vigenciaTrm': '2030-12-31',
    'fechaIngreso': '2026-01-01',
    'tarifa': <String, dynamic>{'id': 51, 'total': 4000},
  };
  if (identificacionConductor != null) {
    json['identificacionConductor'] = identificacionConductor;
  }
  return json;
}

Widget appCon(MockApi mock, {Map<String, WidgetBuilder>? rutas}) => MaterialApp(
  routes: rutas ?? const <String, WidgetBuilder>{},
  home: VehiculosScreen(
    api: VehiculosApi(api: mock.createService(), token: 'jwt'),
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

MockApi backend({String? vigenciaSoat = '2030-12-31'}) => MockApi((request) {
  if (request.method == 'POST') {
    return jsonResponse(vehiculoJson(vigenciaSoat: vigenciaSoat), status: 201);
  }
  if (request.method == 'PUT') {
    return jsonResponse(vehiculoJson(vigenciaSoat: vigenciaSoat));
  }
  if (request.url.path == '/api/vehiculos/BRU001') {
    return jsonResponse(
      vehiculoJson(
        vigenciaSoat: vigenciaSoat,
        identificacionConductor: '9900000002',
      ),
    );
  }
  return jsonResponse(<dynamic>[vehiculoJson(vigenciaSoat: vigenciaSoat)]);
});

void main() {
  testWidgets('lista los vehículos con el token de la sesión', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('BRU001'), findsOneWidget);
    expect(find.text('ACTIVO'), findsOneWidget);
    expect(find.text('BUSETA · Chevrolet 2025'), findsOneWidget);
    expect(find.text('10 puestos'), findsOneWidget);
    expect(find.text('Tarifa \$ 4.000'), findsOneWidget);
    expect(find.text('SOAT 31/12/2030'), findsOneWidget);
    expect(find.text('SOAT VENCIDO'), findsNothing);
    expect(mock.lastRequest.headers['authorization'], 'Bearer jwt');
    expect(mock.lastQuery['page'], '1');
    expect(mock.lastQuery['pageSize'], '20');
    expect(mock.lastQuery.containsKey('placa'), isFalse);
    expect(mock.lastQuery.containsKey('tipo'), isFalse);
  });

  testWidgets('un SOAT vencido se marca en la tarjeta', (tester) async {
    final mock = backend(vigenciaSoat: '2020-01-01');

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('SOAT VENCIDO'), findsOneWidget);
    expect(find.text('SOAT 01/01/2020'), findsOneWidget);
  });

  testWidgets('la búsqueda envía el filtro placa', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.enterText(find.byType(TextFormField), 'BRU');
    await tester.tap(find.widgetWithText(TextButton, 'Buscar'));
    await cargar(tester);

    expect(mock.requests, hasLength(2));
    expect(mock.lastQuery['placa'], 'BRU');
  });

  testWidgets('el filtro de tipo se arma con los tipos recibidos', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Todos los tipos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BUSETA').last);
    await tester.pumpAndSettle();
    await cargar(tester);

    expect(mock.lastQuery['tipo'], 'BUSETA');
    expect(find.text('BUSETA'), findsOneWidget);
  });

  testWidgets('sin resultados muestra el estado vacío', (tester) async {
    final mock = MockApi((_) => jsonResponse(<dynamic>[]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Sin vehículos'), findsOneWidget);
    expect(find.text('Limpiar filtros'), findsOneWidget);
  });

  testWidgets('al tocar la tarjeta consulta el detalle del vehículo', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('BRU001'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.url.path, '/api/vehiculos/BRU001');
    expect(find.text('Capacidad de pasajeros'), findsOneWidget);
    expect(find.text('Tarjeta de propiedad'), findsOneWidget);
    expect(find.text('TP-BRU001'), findsOneWidget);
    expect(find.text('Tarifa asignada'), findsOneWidget);
    expect(find.text('\$ 4.000 (tarifa 51)'), findsOneWidget);
    expect(find.text('Conductor asignado'), findsOneWidget);
    expect(find.text('9900000002'), findsOneWidget);
    expect(find.text('01/01/2026'), findsOneWidget);
  });

  testWidgets('un error del backend se muestra tal cual', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Forbidden',
        'detail': 'No tienes permisos para ver vehículos.',
      }, status: 403),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('No se pudieron cargar los vehículos'), findsOneWidget);
    expect(find.text('No tienes permisos para ver vehículos.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
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

    await tester.tap(find.byTooltip('Nuevo vehículo'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo vehículo'), findsOneWidget);

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'BRU002');
    await tester.enterText(campos.at(1), 'BUSETA');
    await tester.enterText(campos.at(2), 'Chevrolet');
    await tester.enterText(campos.at(3), '2025');
    await tester.enterText(campos.at(4), '10');
    await tester.enterText(campos.at(5), 'TP-BRU002');
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar vehículo'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/vehiculos');
    expect(mock.jsonBody(post)['placa'], 'BRU002');
    expect(mock.jsonBody(post)['capacidadPasajeros'], 10);
    expect(mock.jsonBody(post)['activo'], isTrue);

    expect(find.text('Vehículo BRU001 registrado.'), findsOneWidget);
    expect(mock.lastRequest.method, 'GET');
    expect(find.text('Nuevo vehículo'), findsNothing);
  });

  testWidgets('el detalle permite editar el vehículo', (tester) async {
    pantallaAlta(tester);
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('BRU001'));
    await tester.pumpAndSettle();

    final editar = find.widgetWithText(OutlinedButton, 'Editar vehículo');
    await tester.ensureVisible(editar);
    await tester.tap(editar);
    await tester.pumpAndSettle();

    expect(find.text('Editar vehículo'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tarifa (ID)'),
      '77',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await tester.pumpAndSettle();

    final put = mock.ultimaCon('PUT');
    expect(put.url.path, '/api/vehiculos/BRU001');
    expect(mock.jsonBody(put).containsKey('placa'), isFalse);
    expect(mock.jsonBody(put)['tarifaId'], 77);
    expect(find.text('Vehículo BRU001 actualizado.'), findsOneWidget);
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
    expect(tester.takeException(), isNull);
  });
}
