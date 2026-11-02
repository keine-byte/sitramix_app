import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/models/tarifa/tarifa.dart';
import 'package:sitramix/screens/formulario_tarifa_screen.dart';
import 'package:sitramix/services/remote/tarifas_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> tarifaJson({
  int? id = 3,
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

Widget appCon(
  MockApi mock, {
  void Function(Tarifa?) onResultado = _sinResultado,
}) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final resultado = await Navigator.of(context).push<Tarifa>(
              MaterialPageRoute<Tarifa>(
                builder: (_) => FormularioTarifaScreen(
                  api: TarifasApi(api: mock.createService(), token: 'jwt'),
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

void _sinResultado(Tarifa? resultado) {}

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
  String aportes = '1000',
  String fondo = '2000',
  String aporte = '1000',
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Aportes y gastos varios'),
    aportes,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Fondo de reposición'),
    fondo,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Aporte social del socio'),
    aporte,
  );
}

void main() {
  testWidgets('el alta envía POST y devuelve la tarifa guardada', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(tarifaJson(), status: 201));
    Tarifa? guardada;

    await tester.pumpWidget(
      appCon(mock, onResultado: (resultado) => guardada = resultado),
    );
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar tarifa'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/tarifas');
    expect(post.headers['authorization'], 'Bearer jwt');
    expect(mock.jsonBody(post), <String, dynamic>{
      'aportesGastosVarios': 1000.0,
      'fondoReposicion': 2000.0,
      'aporteSocialSocio': 1000.0,
      'activo': true,
    });
    expect(mock.jsonBody(post).containsKey('total'), isFalse);
    expect(guardada?.id, 3);
  });

  testWidgets('los montos aceptan coma decimal y separador de miles', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(tarifaJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester, aportes: '1.500,50');
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar tarifa'));
    await tester.pumpAndSettle();

    expect(
      mock.jsonBody(mock.ultimaCon('POST'))['aportesGastosVarios'],
      1500.5,
    );
  });

  testWidgets('sin los montos no se envía nada', (tester) async {
    final mock = MockApi((_) => jsonResponse(tarifaJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar tarifa'));
    await tester.pumpAndSettle();

    expect(
      find.text('Escribe el monto de aportes y gastos varios.'),
      findsOneWidget,
    );
    expect(find.text('Escribe el fondo de reposición.'), findsOneWidget);
    expect(find.text('Escribe el aporte social del socio.'), findsOneWidget);
    expect(mock.requests, isEmpty);
  });

  testWidgets('la tarifa se puede crear inactiva', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(tarifaJson(activo: false), status: 201),
    );

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar tarifa'));
    await tester.pumpAndSettle();

    expect(mock.jsonBody(mock.ultimaCon('POST'))['activo'], isFalse);
  });

  testWidgets('un error del backend se muestra dentro del formulario', (
    tester,
  ) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Forbidden',
        'detail': 'Acceso denegado: se requiere el rol GERENTE.',
      }, status: 403),
    );

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar tarifa'));
    await tester.pumpAndSettle();

    expect(
      find.text('Acceso denegado: se requiere el rol GERENTE.'),
      findsOneWidget,
    );
    expect(find.byType(FormularioTarifaScreen), findsOneWidget);
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
        home: FormularioTarifaScreen(
          api: TarifasApi(api: mock.createService(), token: 'jwt'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar tarifa'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de login'), findsOneWidget);
    expect(
      find.text('Tu sesión expiró. Vuelve a iniciar sesión.'),
      findsOneWidget,
    );
  });
}
