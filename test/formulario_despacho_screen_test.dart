import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/models/despacho/despacho.dart';
import 'package:sitramix/screens/formulario_despacho_screen.dart';
import 'package:sitramix/services/remote/despachos_api.dart';
import 'package:sitramix/widgets/forms/form_fields.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> despachoJson({
  int? id = 12,
  String ruta = 'Sincelejo - Cartagena',
  String placa = 'BRU001',
  int pasajeros = 18,
  String estado = 'REGISTRADO',
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
};

Widget appCon(
  MockApi mock, {
  void Function(Despacho?) onResultado = _sinResultado,
}) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final resultado = await Navigator.of(context).push<Despacho>(
              MaterialPageRoute<Despacho>(
                builder: (_) => FormularioDespachoScreen(
                  api: DespachosApi(api: mock.createService(), token: 'jwt'),
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

void _sinResultado(Despacho? resultado) {}

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

Future<void> llenarAlta(
  WidgetTester tester, {
  String ruta = 'Sincelejo - Cartagena',
  String placa = 'bru001',
  String pasajeros = '18',
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Ruta'), ruta);
  await tester.enterText(find.widgetWithText(TextFormField, 'Vehículo'), placa);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Número de pasajeros'),
    pasajeros,
  );
}

void main() {
  testWidgets('el alta envía POST con la placa en mayúsculas', (tester) async {
    final mock = MockApi((_) => jsonResponse(despachoJson(), status: 201));
    Despacho? guardado;

    await tester.pumpWidget(
      appCon(mock, onResultado: (resultado) => guardado = resultado),
    );
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar despacho'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/despachos');
    expect(post.headers['authorization'], 'Bearer jwt');
    expect(mock.jsonBody(post), <String, dynamic>{
      'ruta': 'Sincelejo - Cartagena',
      'placaVehiculo': 'BRU001',
      'numeroPasajeros': 18,
    });
    expect(guardado?.id, 12);
  });

  testWidgets('sin ruta, vehículo o pasajeros no se envía nada', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(despachoJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar despacho'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe la ruta.'), findsOneWidget);
    expect(find.text('Escribe la placa del vehículo.'), findsOneWidget);
    expect(find.text('Escribe el número de pasajeros.'), findsOneWidget);
    expect(mock.requests, isEmpty);
  });

  testWidgets('un despacho sin pasajeros se rechaza', (tester) async {
    final mock = MockApi((_) => jsonResponse(despachoJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester, pasajeros: '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar despacho'));
    await tester.pumpAndSettle();

    expect(find.text('Debe ser mayor que cero.'), findsOneWidget);
    expect(mock.requests, isEmpty);
  });

  testWidgets('la fecha elegida viaja como YYYY-MM-DD', (tester) async {
    final mock = MockApi((_) => jsonResponse(despachoJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.text('Sin fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar despacho'));
    await tester.pumpAndSettle();

    expect(
      mock.jsonBody(mock.ultimaCon('POST'))['fecha'],
      matches(RegExp(r'^\d{4}-\d{2}-01$')),
    );
  });

  testWidgets('la hora elegida viaja como HH:mm:ss', (tester) async {
    final mock = MockApi((_) => jsonResponse(despachoJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.text('Sin hora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar despacho'));
    await tester.pumpAndSettle();

    expect(
      mock.jsonBody(mock.ultimaCon('POST'))['hora'],
      matches(RegExp(r'^\d{2}:\d{2}:00$')),
    );
  });

  testWidgets('un error del backend se muestra dentro del formulario', (
    tester,
  ) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Bad Request',
        'detail': 'El vehículo no está activo.',
      }, status: 400),
    );

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar despacho'));
    await tester.pumpAndSettle();

    expect(find.text('El vehículo no está activo.'), findsOneWidget);
    expect(find.byType(FormularioDespachoScreen), findsOneWidget);
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
        home: FormularioDespachoScreen(
          api: DespachosApi(api: mock.createService(), token: 'jwt'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar despacho'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de login'), findsOneWidget);
    expect(
      find.text('Tu sesión expiró. Vuelve a iniciar sesión.'),
      findsOneWidget,
    );
  });

  test('la hora se formatea como la espera la API', () {
    expect(horaCorta(const TimeOfDay(hour: 8, minute: 5)), '08:05');
    expect(horaApi(const TimeOfDay(hour: 8, minute: 5)), '08:05:00');
    expect(horaApi(const TimeOfDay(hour: 23, minute: 59)), '23:59:00');
  });
}
