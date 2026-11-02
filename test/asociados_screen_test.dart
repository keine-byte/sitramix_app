import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sitramix/screens/asociados_screen.dart';
import 'package:sitramix/services/remote/asociados_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> asociadoJson({
  String identificacion = '1099',
  String nombres = 'Ana Perez',
  bool activo = true,
  String? fechaIngreso,
}) => <String, dynamic>{
  'identificacion': identificacion,
  'nombres': nombres,
  'activo': activo,
  'celular': '3001234567',
  'correo': 'ana@example.com',
  'fechaNacimiento': '1990-05-20',
  'fechaIngreso': ?fechaIngreso,
};

Widget appCon(
  MockApi mock, {
  bool puedeGenerarCredencial = true,
  Map<String, WidgetBuilder>? rutas,
}) => MaterialApp(
  routes: rutas ?? const <String, WidgetBuilder>{},
  home: AsociadosScreen(
    api: AsociadosApi(api: mock.createService(), token: 'jwt'),
    puedeGenerarCredencial: puedeGenerarCredencial,
  ),
);

Future<void> cargar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void pantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

MockApi backend({bool conFechaIngreso = false}) => MockApi((request) {
  if (request.url.path.endsWith('/credencial-temporal')) {
    return jsonResponse(<String, dynamic>{
      'username': 'aperez',
      'passwordTemporal': 'Tmp12345',
    });
  }
  if (request.method == 'POST' || request.method == 'PUT') {
    return jsonResponse(asociadoJson(fechaIngreso: '2026-01-15'));
  }
  if (request.url.path == '/api/asociados/1099') {
    return jsonResponse(
      asociadoJson(fechaIngreso: conFechaIngreso ? '2026-01-15' : null),
    );
  }
  return jsonResponse(<dynamic>[asociadoJson()]);
});

void main() {
  testWidgets('lista los asociados con el token de la sesión', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Ana Perez'), findsOneWidget);
    expect(find.text('ACTIVO'), findsOneWidget);
    expect(find.text('1099'), findsOneWidget);
    expect(find.text('3001234567'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(mock.lastRequest.headers['authorization'], 'Bearer jwt');
    expect(mock.lastQuery['page'], '1');
    expect(mock.lastQuery['pageSize'], '20');
    expect(mock.lastQuery.containsKey('nombres'), isFalse);
    expect(mock.lastQuery.containsKey('activo'), isFalse);
  });

  testWidgets('la búsqueda envía el filtro nombres', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.enterText(find.byType(TextFormField), 'Ana');
    await tester.tap(find.widgetWithText(TextButton, 'Buscar'));
    await cargar(tester);

    expect(mock.requests, hasLength(2));
    expect(mock.lastQuery['nombres'], 'Ana');
    expect(mock.lastQuery['page'], '1');
  });

  testWidgets('filtrar por inactivos envía activo=false', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Inactivos'));
    await cargar(tester);

    expect(mock.lastQuery['activo'], 'false');
  });

  testWidgets('sin resultados muestra el estado vacío', (tester) async {
    final mock = MockApi((_) => jsonResponse(<dynamic>[]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Sin asociados'), findsOneWidget);
    expect(find.text('Limpiar filtros'), findsOneWidget);
  });

  testWidgets('al tocar la tarjeta consulta el detalle del asociado', (
    tester,
  ) async {
    final mock = backend(conFechaIngreso: true);

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Ana Perez'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.method, 'GET');
    expect(mock.lastRequest.url.path, '/api/asociados/1099');
    expect(find.text('Identificación 1099'), findsOneWidget);
    expect(find.text('Fecha de nacimiento'), findsOneWidget);
    expect(find.text('20/05/1990'), findsOneWidget);
    expect(find.text('15/01/2026'), findsOneWidget);
  });

  testWidgets('el GERENTE genera la credencial temporal', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Ana Perez'));
    await tester.pumpAndSettle();

    final boton = find.widgetWithText(
      FilledButton,
      'Generar credencial temporal',
    );
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();

    expect(mock.lastRequest.method, 'POST');
    expect(
      mock.lastRequest.url.path,
      '/api/asociados/1099/credencial-temporal',
    );
    expect(mock.lastRequest.body, isEmpty);
    expect(find.text('Usuario: aperez'), findsOneWidget);
    expect(find.text('Contraseña: Tmp12345'), findsOneWidget);
  });

  testWidgets('el ASISTENTE no ve el botón de credencial temporal', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock, puedeGenerarCredencial: false));
    await cargar(tester);

    await tester.tap(find.text('Ana Perez'));
    await tester.pumpAndSettle();

    expect(find.text('Fecha de ingreso'), findsOneWidget);
    expect(find.text('Generar credencial temporal'), findsNothing);
  });

  testWidgets('un error del backend se muestra tal cual', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Internal Server Error',
        'detail': 'No se pudo consultar el asociado.',
      }, status: 500),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('No se pudieron cargar los asociados'), findsOneWidget);
    expect(find.text('No se pudo consultar el asociado.'), findsOneWidget);
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

    await tester.tap(find.byTooltip('Nuevo asociado'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo asociado'), findsOneWidget);

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), '2001');
    await tester.enterText(campos.at(1), 'Luis Gomez');
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar asociado'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/asociados');
    expect(mock.jsonBody(post)['identificacion'], '2001');
    expect(mock.jsonBody(post)['nombres'], 'Luis Gomez');
    expect(mock.jsonBody(post)['activo'], isTrue);

    expect(find.text('Asociado 1099 registrado.'), findsOneWidget);
    expect(mock.lastRequest.method, 'GET');
    expect(find.text('Nuevo asociado'), findsNothing);
  });

  testWidgets('el detalle permite editar el asociado', (tester) async {
    pantallaAlta(tester);
    final mock = backend(conFechaIngreso: true);

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Ana Perez'));
    await tester.pumpAndSettle();

    final editar = find.widgetWithText(OutlinedButton, 'Editar asociado');
    await tester.ensureVisible(editar);
    await tester.tap(editar);
    await tester.pumpAndSettle();

    expect(find.text('Editar asociado'), findsOneWidget);
    expect(find.text('Fecha de ingreso'), findsOneWidget);

    final nombres = find.byType(TextFormField).at(1);
    await tester.enterText(nombres, 'Ana Perez Diaz');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await tester.pumpAndSettle();

    final put = mock.ultimaCon('PUT');
    expect(put.url.path, '/api/asociados/1099');
    expect(mock.jsonBody(put)['nombres'], 'Ana Perez Diaz');
    expect(mock.jsonBody(put).containsKey('identificacion'), isFalse);
    expect(mock.jsonBody(put)['fechaIngreso'], '2026-01-15');
  });

  testWidgets('un fallo de red se explica en español', (tester) async {
    final mock = MockApi((_) => throw http.ClientException('sin red'));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(
      find.text('No se pudo conectar con la API. Revisa tu conexión.'),
      findsOneWidget,
    );
  });

  testWidgets('no desborda en una pantalla de 320x640', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Ana Perez'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
