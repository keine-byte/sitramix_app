import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/screens/tarifas_screen.dart';
import 'package:sitramix/services/remote/tarifas_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> tarifaJson({
  int? id = 1,
  bool activo = true,
  double aportes = 1000,
  double fondo = 2000,
  double aporte = 1000,
  double total = 4000,
}) => <String, dynamic>{
  'id': id,
  'aportesGastosVarios': aportes,
  'fondoReposicion': fondo,
  'aporteSocialSocio': aporte,
  'total': total,
  'activo': activo,
};

Widget appCon(MockApi mock, {Map<String, WidgetBuilder>? rutas}) => MaterialApp(
  routes: rutas ?? const <String, WidgetBuilder>{},
  home: TarifasScreen(
    api: TarifasApi(api: mock.createService(), token: 'jwt'),
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
    return jsonResponse(tarifaJson(id: 3), status: 201);
  }
  if (request.method == 'DELETE') {
    return jsonResponse(tarifaJson(activo: false));
  }
  if (request.url.path == '/api/tarifas/1') return jsonResponse(tarifaJson());
  final inactivas = tarifaJson(
    id: 2,
    activo: false,
    aportes: 1500,
    total: 5000,
  );
  if (request.url.queryParameters['activo'] == 'false') {
    return jsonResponse(<dynamic>[inactivas]);
  }
  return jsonResponse(<dynamic>[tarifaJson(), inactivas]);
});

void main() {
  testWidgets('lista las tarifas con el token y de 20 en 20', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(mock.lastRequest.url.path, '/api/tarifas');
    expect(mock.lastRequest.headers['authorization'], 'Bearer jwt');
    expect(mock.lastQuery['pageSize'], '20');
    expect(find.text('Tarifa #1'), findsOneWidget);
    expect(find.text('Tarifa #2'), findsOneWidget);
    expect(find.text('ACTIVA'), findsOneWidget);
    expect(find.text('INACTIVA'), findsOneWidget);
    expect(find.text('Total \$ 4.000'), findsOneWidget);
    expect(find.text('Total \$ 5.000'), findsOneWidget);
    expect(find.text('Aportes y gastos varios \$ 1.500'), findsOneWidget);
  });

  testWidgets('filtra por tarifas activas e inactivas', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Activas'));
    await cargar(tester);
    expect(mock.lastQuery['activo'], 'true');

    await tester.tap(find.text('Inactivas'));
    await cargar(tester);
    expect(mock.lastQuery['activo'], 'false');
    expect(find.text('Tarifa #1'), findsNothing);

    await tester.tap(find.text('Todas'));
    await cargar(tester);
    expect(mock.lastQuery.containsKey('activo'), isFalse);
  });

  testWidgets('al tocar la tarjeta consulta el detalle con los montos', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Tarifa #1'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.url.path, '/api/tarifas/1');
    expect(find.text('Aportes y gastos varios'), findsOneWidget);
    expect(find.text('Fondo de reposición'), findsOneWidget);
    expect(find.text('Aporte social socio'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Inactivar tarifa'), findsOneWidget);
  });

  testWidgets('inactivar envía el DELETE y deja la tarifa inactiva', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Tarifa #1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Inactivar tarifa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inactivar tarifa'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Inactivar'));
    await tester.pumpAndSettle();

    final borrado = mock.ultimaCon('DELETE');
    expect(borrado.url.path, '/api/tarifas/1');
    expect(borrado.body, isEmpty);
    expect(find.text('La tarifa ya está inactiva.'), findsOneWidget);
    expect(find.text('Inactivar tarifa'), findsNothing);
  });

  testWidgets('sin tarifas muestra el estado vacío', (tester) async {
    final mock = MockApi((_) => jsonResponse(<dynamic>[]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Sin tarifas'), findsOneWidget);
    expect(find.text('No hay tarifas para este filtro.'), findsOneWidget);
    expect(find.text('Ver todas'), findsOneWidget);
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

    await tester.tap(find.byTooltip('Nueva tarifa'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva tarifa'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Aportes y gastos varios'),
      '2500',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fondo de reposición'),
      '1000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Aporte social del socio'),
      '500',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar tarifa'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/tarifas');
    expect(mock.jsonBody(post), <String, dynamic>{
      'aportesGastosVarios': 2500.0,
      'fondoReposicion': 1000.0,
      'aporteSocialSocio': 500.0,
      'activo': true,
    });

    expect(find.text('Tarifa #3 registrada.'), findsOneWidget);
    expect(mock.lastRequest.method, 'GET');
    expect(find.text('Nueva tarifa'), findsNothing);
  });

  testWidgets('un ASISTENTE recibe el 403 tal cual', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Forbidden',
        'detail': 'Acceso denegado: se requiere el rol GERENTE.',
      }, status: 403),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('No se pudieron cargar las tarifas'), findsOneWidget);
    expect(
      find.text('Acceso denegado: se requiere el rol GERENTE.'),
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

    expect(find.text('Tarifa #1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
