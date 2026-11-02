import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/screens/conductores_screen.dart';
import 'package:sitramix/services/remote/conductores_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> conductorJson({
  String identificacion = '1099999',
  String nombres = 'Ana Perez',
  bool activo = true,
  String? vigenciaLicencia = '2099-01-01',
}) => <String, dynamic>{
  'identificacion': identificacion,
  'nombres': nombres,
  'activo': activo,
  'fechaNacimiento': '1990-05-20',
  'numeroLicencia': 'LIC-7788',
  'categoriaLicencia': 'C2',
  'vigenciaLicencia': vigenciaLicencia,
  'celular': '3001234567',
  'correo': 'ana@example.com',
};

Widget appCon(MockApi mock, {Map<String, WidgetBuilder>? rutas}) => MaterialApp(
  routes: rutas ?? const <String, WidgetBuilder>{},
  home: ConductoresScreen(
    api: ConductoresApi(api: mock.createService(), token: 'jwt'),
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

MockApi backend({String? vigenciaLicencia = '2099-01-01'}) =>
    MockApi((request) {
      if (request.method == 'POST') {
        return jsonResponse(
          conductorJson(identificacion: '2001', nombres: 'Luis Gomez'),
          status: 201,
        );
      }
      if (request.method == 'PUT') {
        return jsonResponse(conductorJson(vigenciaLicencia: vigenciaLicencia));
      }
      if (request.url.path == '/api/conductores/1099999') {
        return jsonResponse(conductorJson(vigenciaLicencia: vigenciaLicencia));
      }
      return jsonResponse(<dynamic>[
        conductorJson(vigenciaLicencia: vigenciaLicencia),
      ]);
    });

void main() {
  testWidgets('lista los conductores con el token de la sesión', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Ana Perez'), findsOneWidget);
    expect(find.text('ACTIVO'), findsOneWidget);
    expect(find.text('1099999'), findsOneWidget);
    expect(find.text('Licencia C2 · LIC-7788'), findsOneWidget);
    expect(find.text('Vigencia 01/01/2099'), findsOneWidget);
    expect(find.text('VENCIDA'), findsNothing);
    expect(mock.lastRequest.headers['authorization'], 'Bearer jwt');
    expect(mock.lastQuery['page'], '1');
    expect(mock.lastQuery['pageSize'], '20');
  });

  testWidgets('una licencia vencida se marca en la tarjeta', (tester) async {
    final mock = backend(vigenciaLicencia: '2020-01-01');

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('VENCIDA'), findsOneWidget);
    expect(find.text('Vigencia 01/01/2020'), findsOneWidget);
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

    expect(find.text('Sin conductores'), findsOneWidget);
    expect(find.text('Limpiar filtros'), findsOneWidget);
  });

  testWidgets('al tocar la tarjeta consulta el detalle del conductor', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Ana Perez'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.url.path, '/api/conductores/1099999');
    expect(find.text('Identificación 1099999'), findsOneWidget);
    expect(find.text('Número de licencia'), findsOneWidget);
    expect(find.text('LIC-7788'), findsOneWidget);
    expect(find.text('Categoría'), findsOneWidget);
    expect(find.text('20/05/1990'), findsOneWidget);
  });

  testWidgets('un error del backend se muestra tal cual', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Forbidden',
        'detail': 'No tienes permisos para ver conductores.',
      }, status: 403),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('No se pudieron cargar los conductores'), findsOneWidget);
    expect(
      find.text('No tienes permisos para ver conductores.'),
      findsOneWidget,
    );
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

    await tester.tap(find.byTooltip('Nuevo conductor'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo conductor'), findsOneWidget);

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), '2001');
    await tester.enterText(campos.at(1), 'Luis Gomez');
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar conductor'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/conductores');
    expect(mock.jsonBody(post)['identificacion'], '2001');
    expect(mock.jsonBody(post)['nombres'], 'Luis Gomez');
    expect(mock.jsonBody(post)['activo'], isTrue);

    expect(find.text('Conductor 2001 registrado.'), findsOneWidget);
    expect(mock.lastRequest.method, 'GET');
    expect(find.text('Nuevo conductor'), findsNothing);
  });

  testWidgets('el detalle permite editar el conductor', (tester) async {
    pantallaAlta(tester);
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Ana Perez'));
    await tester.pumpAndSettle();

    final editar = find.widgetWithText(OutlinedButton, 'Editar conductor');
    await tester.ensureVisible(editar);
    await tester.tap(editar);
    await tester.pumpAndSettle();

    expect(find.text('Editar conductor'), findsOneWidget);

    final nombres = find.byType(TextFormField).at(1);
    await tester.enterText(nombres, 'Ana Perez Diaz');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await tester.pumpAndSettle();

    final put = mock.ultimaCon('PUT');
    expect(put.url.path, '/api/conductores/1099999');
    expect(mock.jsonBody(put)['nombres'], 'Ana Perez Diaz');
    expect(mock.jsonBody(put).containsKey('identificacion'), isFalse);
    expect(mock.jsonBody(put)['vigenciaLicencia'], '2099-01-01');
    expect(find.text('Conductor 1099999 actualizado.'), findsOneWidget);
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
