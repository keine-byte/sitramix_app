import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/models/asociado/asociado.dart';
import 'package:sitramix/screens/formulario_asociado_screen.dart';
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

Asociado asociadoDePrueba() => Asociado(
  identificacion: '1099',
  nombres: 'Ana Perez',
  activo: true,
  celular: '3001234567',
  correo: 'ana@example.com',
  fechaNacimiento: DateTime(1990, 5, 20),
  fechaIngreso: DateTime(2026, 1, 15),
);

Widget appCon(
  MockApi mock, {
  Asociado? asociado,
  void Function(Asociado?) onResultado = _sinResultado,
}) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final resultado = await Navigator.of(context).push<Asociado>(
              MaterialPageRoute<Asociado>(
                builder: (_) => FormularioAsociadoScreen(
                  api: AsociadosApi(api: mock.createService(), token: 'jwt'),
                  asociado: asociado,
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

void _sinResultado(Asociado? resultado) {}

Future<void> abrir(WidgetTester tester) async {
  pantallaAlta(tester);
  await tester.tap(find.text('Abrir formulario'));
  await tester.pumpAndSettle();
}

void pantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('el alta envía POST y devuelve el asociado guardado', (
    tester,
  ) async {
    final mock = MockApi(
      (_) => jsonResponse(asociadoJson(identificacion: '2001'), status: 201),
    );
    Asociado? guardado;

    await tester.pumpWidget(
      appCon(mock, onResultado: (resultado) => guardado = resultado),
    );
    await abrir(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Identificación'),
      '2001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombres'),
      'Luis Gomez',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Celular'),
      '3009998877',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar asociado'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/asociados');
    expect(post.headers['authorization'], 'Bearer jwt');
    expect(mock.jsonBody(post)['identificacion'], '2001');
    expect(mock.jsonBody(post)['nombres'], 'Luis Gomez');
    expect(mock.jsonBody(post)['celular'], '3009998877');
    expect(mock.jsonBody(post)['activo'], isTrue);
    expect(mock.jsonBody(post).containsKey('fechaIngreso'), isFalse);

    expect(guardado?.identificacion, '2001');
    expect(find.byType(FormularioAsociadoScreen), findsNothing);
  });

  testWidgets('el alta exige identificación y nombres antes de enviar', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(asociadoJson()));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar asociado'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe la identificación.'), findsOneWidget);
    expect(find.text('Escribe los nombres.'), findsOneWidget);
    expect(mock.requests, isEmpty);
  });

  testWidgets('la edición envía PUT sin la identificación', (tester) async {
    final mock = MockApi((_) => jsonResponse(asociadoJson()));
    Asociado? guardado;

    await tester.pumpWidget(
      appCon(
        mock,
        asociado: asociadoDePrueba(),
        onResultado: (resultado) => guardado = resultado,
      ),
    );
    await abrir(tester);

    expect(find.text('Editar asociado'), findsOneWidget);
    expect(find.text('Fecha de ingreso'), findsOneWidget);
    expect(find.text('20/05/1990'), findsOneWidget);
    expect(find.text('15/01/2026'), findsOneWidget);

    final identificacion = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Identificación'),
    );
    expect(identificacion.enabled, isFalse);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombres'),
      'Ana Perez Diaz',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await tester.pumpAndSettle();

    final put = mock.ultimaCon('PUT');
    expect(put.url.path, '/api/asociados/1099');
    expect(mock.jsonBody(put)['nombres'], 'Ana Perez Diaz');
    expect(mock.jsonBody(put).containsKey('identificacion'), isFalse);
    expect(mock.jsonBody(put)['fechaIngreso'], '2026-01-15');
    expect(mock.jsonBody(put)['fechaNacimiento'], '1990-05-20');
    expect(guardado?.nombres, 'Ana Perez');
  });

  testWidgets('la fecha elegida viaja como YYYY-MM-DD y se puede quitar', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(asociadoJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Identificación'),
      '2001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombres'),
      'Luis Gomez',
    );

    await tester.tap(find.text('Sin fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('01/01/1990'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar asociado'));
    await tester.pumpAndSettle();

    expect(
      mock.jsonBody(mock.ultimaCon('POST'))['fechaNacimiento'],
      '1990-01-01',
    );

    await tester.pumpWidget(appCon(mock, asociado: asociadoDePrueba()));
    await abrir(tester);
    await tester.tap(find.byTooltip('Quitar fecha').first);
    await tester.pumpAndSettle();
    expect(find.text('20/05/1990'), findsNothing);
  });

  testWidgets('un error del backend se muestra dentro del formulario', (
    tester,
  ) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Conflict',
        'detail': 'La identificación ya está registrada.',
      }, status: 409),
    );

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Identificación'),
      '1099',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombres'),
      'Ana Perez',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar asociado'));
    await tester.pumpAndSettle();

    expect(find.text('La identificación ya está registrada.'), findsOneWidget);
    expect(find.byType(FormularioAsociadoScreen), findsOneWidget);
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
        home: FormularioAsociadoScreen(
          api: AsociadosApi(api: mock.createService(), token: 'jwt'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Identificación'),
      '2001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombres'),
      'Luis Gomez',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar asociado'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de login'), findsOneWidget);
    expect(
      find.text('Tu sesión expiró. Vuelve a iniciar sesión.'),
      findsOneWidget,
    );
  });
}
