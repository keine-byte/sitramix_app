import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/models/conductor/conductor.dart';
import 'package:sitramix/screens/formulario_conductor_screen.dart';
import 'package:sitramix/services/remote/conductores_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> conductorJson({
  String identificacion = '1099',
  String nombres = 'Ana Perez',
  bool activo = true,
  String? vigenciaLicencia = '2030-01-01',
}) => <String, dynamic>{
  'identificacion': identificacion,
  'nombres': nombres,
  'activo': activo,
  'fechaNacimiento': '1990-05-20',
  'numeroLicencia': 'LIC-7788',
  'categoriaLicencia': 'C2',
  'vigenciaLicencia': ?vigenciaLicencia,
  'celular': '3001234567',
  'correo': 'ana@example.com',
};

Conductor conductorDePrueba() => Conductor(
  identificacion: '1099',
  nombres: 'Ana Perez',
  activo: true,
  fechaNacimiento: DateTime(1990, 5, 20),
  numeroLicencia: 'LIC-7788',
  categoriaLicencia: 'C2',
  vigenciaLicencia: DateTime(2030, 1, 1),
  celular: '3001234567',
  correo: 'ana@example.com',
);

Widget appCon(
  MockApi mock, {
  Conductor? conductor,
  void Function(Conductor?) onResultado = _sinResultado,
}) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final resultado = await Navigator.of(context).push<Conductor>(
              MaterialPageRoute<Conductor>(
                builder: (_) => FormularioConductorScreen(
                  api: ConductoresApi(api: mock.createService(), token: 'jwt'),
                  conductor: conductor,
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

void _sinResultado(Conductor? resultado) {}

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
  testWidgets('el alta envía POST y devuelve el conductor guardado', (
    tester,
  ) async {
    final mock = MockApi(
      (_) => jsonResponse(conductorJson(identificacion: '2001'), status: 201),
    );
    Conductor? guardado;

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
      find.widgetWithText(TextFormField, 'Número de licencia'),
      'LIC-9911',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Categoría de la licencia'),
      'C3',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Celular'),
      '3009998877',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar conductor'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/conductores');
    expect(post.headers['authorization'], 'Bearer jwt');
    expect(mock.jsonBody(post), <String, dynamic>{
      'identificacion': '2001',
      'nombres': 'Luis Gomez',
      'activo': true,
      'numeroLicencia': 'LIC-9911',
      'categoriaLicencia': 'C3',
      'celular': '3009998877',
    });
    expect(guardado?.identificacion, '2001');
  });

  testWidgets('sin identificación ni nombres no se envía nada', (tester) async {
    final mock = MockApi((_) => jsonResponse(conductorJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar conductor'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe la identificación.'), findsOneWidget);
    expect(find.text('Escribe los nombres.'), findsOneWidget);
    expect(mock.requests, isEmpty);
  });

  testWidgets('la edición envía PUT sin la identificación', (tester) async {
    final mock = MockApi((_) => jsonResponse(conductorJson()));
    Conductor? guardado;

    await tester.pumpWidget(
      appCon(
        mock,
        conductor: conductorDePrueba(),
        onResultado: (resultado) => guardado = resultado,
      ),
    );
    await abrir(tester);

    expect(find.text('Editar conductor'), findsWidgets);
    final identificacion = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Identificación'),
    );
    expect(identificacion.enabled, isFalse);
    expect(find.text('20/05/1990'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await tester.pumpAndSettle();

    final put = mock.ultimaCon('PUT');
    expect(put.url.path, '/api/conductores/1099');
    final cuerpo = mock.jsonBody(put);
    expect(cuerpo.containsKey('identificacion'), isFalse);
    expect(cuerpo['nombres'], 'Ana Perez');
    expect(cuerpo['activo'], isFalse);
    expect(cuerpo['numeroLicencia'], 'LIC-7788');
    expect(cuerpo['categoriaLicencia'], 'C2');
    expect(cuerpo['vigenciaLicencia'], '2030-01-01');
    expect(cuerpo['fechaNacimiento'], '1990-05-20');
    expect(guardado?.nombres, 'Ana Perez');
  });

  testWidgets('la fecha de nacimiento elegida viaja como YYYY-MM-DD', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(conductorJson(), status: 201));

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

    await tester.tap(find.text('Sin fecha').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('01/01/1990'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar conductor'));
    await tester.pumpAndSettle();

    expect(
      mock.jsonBody(mock.ultimaCon('POST'))['fechaNacimiento'],
      '1990-01-01',
    );
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
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar conductor'));
    await tester.pumpAndSettle();

    expect(find.text('La identificación ya está registrada.'), findsOneWidget);
    expect(find.byType(FormularioConductorScreen), findsOneWidget);
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
        home: FormularioConductorScreen(
          api: ConductoresApi(api: mock.createService(), token: 'jwt'),
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
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar conductor'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de login'), findsOneWidget);
    expect(
      find.text('Tu sesión expiró. Vuelve a iniciar sesión.'),
      findsOneWidget,
    );
  });
}
