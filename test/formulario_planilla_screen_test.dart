import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/models/planilla/planilla.dart';
import 'package:sitramix/screens/formulario_planilla_screen.dart';
import 'package:sitramix/services/remote/planillas_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> planillaJson({int numero = 25}) => <String, dynamic>{
  'numero': numero,
  'fecha': '2026-10-27',
  'hora': '08:30:00',
  'placaVehiculo': 'BRU001',
  'tipo': 'VIAJE',
  'estado': 'ACTIVA',
  'tarifaId': 3,
  'valorPagado': 17000,
  'estadoPago': 'PENDIENTE',
  'conductor': <String, dynamic>{
    'Identificacion': '1099999',
    'Nombre del conductor': 'Ana Perez',
  },
};

Widget appCon(
  MockApi mock, {
  void Function(Planilla?) onResultado = _sinResultado,
}) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final resultado = await Navigator.of(context).push<Planilla>(
              MaterialPageRoute<Planilla>(
                builder: (_) => FormularioPlanillaScreen(
                  api: PlanillasApi(api: mock.createService(), token: 'jwt'),
                ),
              ),
            );
            onResultado(resultado);
          },
          child: const Text('Abrir formulario'),
        ),
      ),
    ),
  ),
);

void _sinResultado(Planilla? resultado) {}

void pantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> abrir(WidgetTester tester) async {
  pantallaAlta(tester);
  await tester.tap(find.text('Abrir formulario'));
  await tester.pumpAndSettle();
}

Future<void> elegirDia1(WidgetTester tester) async {
  await tester.tap(find.text('Sin fecha'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('1').last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> llenarAlta(
  WidgetTester tester, {
  String placa = 'bru001',
  String tipo = 'VIAJE',
  String tarifa = '3',
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Vehículo'), placa);
  await tester.enterText(find.widgetWithText(TextFormField, 'Tipo'), tipo);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Tarifa (ID)'),
    tarifa,
  );
}

void main() {
  testWidgets('el alta envía POST con los cinco campos obligatorios', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(planillaJson(), status: 201));
    Planilla? guardada;

    await tester.pumpWidget(
      appCon(mock, onResultado: (resultado) => guardada = resultado),
    );
    await abrir(tester);

    await elegirDia1(tester);
    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar planilla'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/planillas');
    expect(post.headers['authorization'], 'Bearer jwt');
    final cuerpo = mock.jsonBody(post);
    expect(cuerpo['fecha'], matches(RegExp(r'^\d{4}-\d{2}-01$')));
    expect(cuerpo['placaVehiculo'], 'BRU001');
    expect(cuerpo['tipo'], 'VIAJE');
    expect(cuerpo['estado'], 'ACTIVA');
    expect(cuerpo['tarifaId'], 3);
    expect(cuerpo.keys, hasLength(5));
    expect(guardada?.numero, 25);
    expect(guardada?.valorPagado, 17000);
  });

  testWidgets('sin fecha no se envía nada', (tester) async {
    final mock = MockApi((_) => jsonResponse(planillaJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar planilla'));
    await tester.pumpAndSettle();

    expect(find.text('Elige la fecha de la planilla.'), findsOneWidget);
    expect(mock.requests, isEmpty);
  });

  testWidgets('sin placa, tipo ni tarifa se avisa en cada campo', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(planillaJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await elegirDia1(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Tipo'), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar planilla'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe la placa del vehículo.'), findsOneWidget);
    expect(find.text('Escribe el tipo de planilla.'), findsOneWidget);
    expect(find.text('Escribe el ID de la tarifa.'), findsOneWidget);
    expect(mock.requests, isEmpty);
  });

  testWidgets('una tarifa 0 se rechaza antes de enviar', (tester) async {
    final mock = MockApi((_) => jsonResponse(planillaJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await elegirDia1(tester);
    await llenarAlta(tester, tarifa: '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar planilla'));
    await tester.pumpAndSettle();

    expect(
      find.text('El ID de la tarifa debe ser mayor que cero.'),
      findsOneWidget,
    );
    expect(mock.requests, isEmpty);
  });

  testWidgets('un 400 por sanción activa se muestra en el formulario', (
    tester,
  ) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Bad Request',
        'detail': 'El conductor tiene una sanción ACTIVA en esa fecha.',
      }, status: 400),
    );

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await elegirDia1(tester);
    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar planilla'));
    await tester.pumpAndSettle();

    expect(
      find.text('El conductor tiene una sanción ACTIVA en esa fecha.'),
      findsOneWidget,
    );
    expect(find.byType(FormularioPlanillaScreen), findsOneWidget);
  });

  testWidgets('un 401 cierra la sesión y vuelve al login', (tester) async {
    pantallaAlta(tester);
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'detail': 'Token expirado.',
      }, status: 401),
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: <String, WidgetBuilder>{
          '/login': (_) => const Scaffold(body: Text('Pantalla de login')),
        },
        home: FormularioPlanillaScreen(
          api: PlanillasApi(api: mock.createService(), token: 'jwt'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await elegirDia1(tester);
    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar planilla'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de login'), findsOneWidget);
    expect(
      find.text('Tu sesión expiró. Vuelve a iniciar sesión.'),
      findsOneWidget,
    );
  });
}
