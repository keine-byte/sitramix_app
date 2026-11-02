import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/models/sancion/sancion.dart';
import 'package:sitramix/screens/formulario_sancion_screen.dart';
import 'package:sitramix/services/remote/sanciones_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> sancionJson({
  int? id = 7,
  String estado = 'ACTIVA',
  String motivo = 'Reiteración de retrasos',
}) => <String, dynamic>{
  'id': id,
  'identificacionConductor': '1712345678',
  'nombresConductor': 'Luis Conductor',
  'motivo': motivo,
  'fechaInicio': '2026-10-01',
  'fechaFin': '2026-10-31',
  'fechaRegistro': '2026-10-01T09:30:00-05:00',
  'estado': estado,
};

Widget appCon(
  MockApi mock, {
  void Function(Sancion?) onResultado = _sinResultado,
}) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final resultado = await Navigator.of(context).push<Sancion>(
              MaterialPageRoute<Sancion>(
                builder: (_) => FormularioSancionScreen(
                  api: SancionesApi(api: mock.createService(), token: 'jwt'),
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

void _sinResultado(Sancion? resultado) {}

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
  String conductor = '1712345678',
  String motivo = 'Reiteración de retrasos',
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Conductor'),
    conductor,
  );
  await tester.enterText(find.widgetWithText(TextFormField, 'Motivo'), motivo);
}

void main() {
  testWidgets('el alta envía POST con conductor y motivo', (tester) async {
    final mock = MockApi((_) => jsonResponse(sancionJson(), status: 201));
    Sancion? guardada;

    await tester.pumpWidget(
      appCon(mock, onResultado: (resultado) => guardada = resultado),
    );
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar sanción'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/sanciones');
    expect(post.headers['authorization'], 'Bearer jwt');
    expect(mock.jsonBody(post), <String, dynamic>{
      'identificacionConductor': '1712345678',
      'motivo': 'Reiteración de retrasos',
    });
    expect(guardada?.id, 7);
    expect(guardada?.estado, EstadoSancion.activa);
  });

  testWidgets('sin conductor ni motivo no se envía nada', (tester) async {
    final mock = MockApi((_) => jsonResponse(sancionJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar sanción'));
    await tester.pumpAndSettle();

    expect(
      find.text('Escribe la identificación del conductor.'),
      findsOneWidget,
    );
    expect(find.text('Escribe el motivo de la sanción.'), findsOneWidget);
    expect(mock.requests, isEmpty);
  });

  testWidgets('un motivo de solo espacios no se acepta', (tester) async {
    final mock = MockApi((_) => jsonResponse(sancionJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester, motivo: '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar sanción'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe el motivo de la sanción.'), findsOneWidget);
    expect(mock.requests, isEmpty);
  });

  testWidgets('las fechas elegidas viajan como YYYY-MM-DD', (tester) async {
    final mock = MockApi((_) => jsonResponse(sancionJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.text('Sin fecha').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sin fecha').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar sanción'));
    await tester.pumpAndSettle();

    final cuerpo = mock.jsonBody(mock.ultimaCon('POST'));
    expect(cuerpo['fechaInicio'], matches(RegExp(r'^\d{4}-\d{2}-01$')));
    expect(cuerpo['fechaFin'], matches(RegExp(r'^\d{4}-\d{2}-15$')));
  });

  testWidgets('el intervalo se puede dejar sin fechas', (tester) async {
    final mock = MockApi((_) => jsonResponse(sancionJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.text('Sin fecha').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.textContaining(RegExp(r'^\d{2}/\d{2}/\d{4}$')), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar fecha'));
    await tester.pumpAndSettle();
    expect(find.text('Sin fecha'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar sanción'));
    await tester.pumpAndSettle();

    expect(
      mock.jsonBody(mock.ultimaCon('POST')).containsKey('fechaInicio'),
      isFalse,
    );
  });

  testWidgets('un error del backend se muestra dentro del formulario', (
    tester,
  ) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Conflict',
        'detail': 'El conductor ya tiene una sanción activa en ese rango.',
      }, status: 409),
    );

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar sanción'));
    await tester.pumpAndSettle();

    expect(
      find.text('El conductor ya tiene una sanción activa en ese rango.'),
      findsOneWidget,
    );
    expect(find.byType(FormularioSancionScreen), findsOneWidget);
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
        home: FormularioSancionScreen(
          api: SancionesApi(api: mock.createService(), token: 'jwt'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar sanción'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de login'), findsOneWidget);
    expect(
      find.text('Tu sesión expiró. Vuelve a iniciar sesión.'),
      findsOneWidget,
    );
  });
}
