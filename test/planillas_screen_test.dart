import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sitramix/screens/planillas_screen.dart';
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

Widget appCon(MockApi mock, {Map<String, WidgetBuilder>? rutas}) => MaterialApp(
  routes: rutas ?? const <String, WidgetBuilder>{},
  home: PlanillasScreen(
    api: PlanillasApi(api: mock.createService(), token: 'jwt'),
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

void main() {
  testWidgets('lista las planillas del backend con el token de la sesión', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(<dynamic>[planillaJson()]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Planilla 25'), findsOneWidget);
    expect(find.text('ACTIVA'), findsOneWidget);
    expect(find.text('PENDIENTE'), findsOneWidget);
    expect(find.text('27/10/2026 · 08:30'), findsOneWidget);
    expect(find.text('BRU001 · VIAJE'), findsOneWidget);
    expect(find.text('Ana Perez (1099999)'), findsOneWidget);
    expect(find.text('\$ 17.000'), findsOneWidget);
    expect(mock.lastRequest.headers['authorization'], 'Bearer jwt');
    expect(mock.lastQuery['page'], '1');
    expect(mock.lastQuery['pageSize'], '20');
    expect(mock.lastQuery.containsKey('estado'), isFalse);
    expect(mock.lastQuery.containsKey('fecha'), isFalse);
  });

  testWidgets('un error del backend se muestra tal cual', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Forbidden',
        'detail': 'No tienes permisos para ver planillas.',
      }, status: 403),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('No se pudieron cargar las planillas'), findsOneWidget);
    expect(find.text('No tienes permisos para ver planillas.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('un 401 limpia la sesión y vuelve al login', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'detail': 'Tu sesión expiró. Vuelve a iniciar sesión.',
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
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('sin resultados muestra el estado vacío', (tester) async {
    final mock = MockApi((_) => jsonResponse(<dynamic>[]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Sin planillas'), findsOneWidget);
    expect(find.text('Limpiar filtros'), findsOneWidget);
  });

  testWidgets('filtrar por estado vuelve a consultar con estado', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(<dynamic>[planillaJson()]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Anuladas'));
    await cargar(tester);

    expect(mock.requests, hasLength(2));
    expect(mock.lastQuery['estado'], 'ANULADA');
  });

  testWidgets('anular confirma, llama al DELETE y actualiza la tarjeta', (
    tester,
  ) async {
    final mock = MockApi(
      (request) => request.method == 'DELETE'
          ? jsonResponse(planillaJson(estado: 'ANULADA'))
          : jsonResponse(<dynamic>[planillaJson()]),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Anular'));
    await tester.pumpAndSettle();
    expect(find.text('Anular planilla 25'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Anular'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.method, 'DELETE');
    expect(mock.lastRequest.url.path, '/api/planillas/25');
    expect(find.text('ANULADA'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Anular'), findsNothing);
    expect(find.text('Planilla 25 anulada.'), findsOneWidget);
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

    final mock = MockApi((_) => jsonResponse(<dynamic>[planillaJson()]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Planilla 25'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la barra abre el alta de planillas masivas', (tester) async {
    final mock = MockApi((_) => jsonResponse(<dynamic>[planillaJson()]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.byTooltip('Planilla masiva'));
    await tester.pumpAndSettle();

    expect(find.text('Planillas masivas'), findsOneWidget);
    expect(find.text('Registrar planillas'), findsOneWidget);
    expect(find.text('Elegir fecha'), findsOneWidget);
  });

  testWidgets('la barra registra una planilla individual y refresca', (
    tester,
  ) async {
    pantallaAlta(tester);
    var creadas = 0;
    final mock = MockApi((request) {
      if (request.method == 'POST') {
        creadas++;
        return jsonResponse(planillaJson(numero: 26), status: 201);
      }
      return jsonResponse(<dynamic>[
        planillaJson(),
        if (creadas > 0) planillaJson(numero: 26),
      ]);
    });

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.byTooltip('Nueva planilla'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva planilla'), findsOneWidget);

    await tester.tap(find.text('Sin fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vehículo'),
      'bru001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tarifa (ID)'),
      '3',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar planilla'));
    await tester.pumpAndSettle();

    expect(mock.ultimaCon('POST').url.path, '/api/planillas');
    expect(find.text('Planilla 26 registrada.'), findsOneWidget);
    expect(find.text('Planilla 26'), findsOneWidget);
    expect(mock.requests, hasLength(3));
  });
}
