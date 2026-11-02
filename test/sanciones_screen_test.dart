import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/screens/sanciones_screen.dart';
import 'package:sitramix/services/remote/sanciones_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> sancionJson({
  int? id = 1,
  String estado = 'ACTIVA',
  String inicio = '2000-01-01',
  String fin = '2099-12-31',
  String motivo = 'Conducción temeraria',
  String nombres = 'Luis Conductor',
}) => <String, dynamic>{
  'id': id,
  'identificacionConductor': '1712345678',
  'nombresConductor': nombres,
  'motivo': motivo,
  'fechaInicio': inicio,
  'fechaFin': fin,
  'fechaRegistro': '2026-10-01T09:30:00-05:00',
  'estado': estado,
};

Widget appCon(MockApi mock, {Map<String, WidgetBuilder>? rutas}) => MaterialApp(
  routes: rutas ?? const <String, WidgetBuilder>{},
  home: SancionesScreen(
    api: SancionesApi(api: mock.createService(), token: 'jwt'),
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
    return jsonResponse(sancionJson(id: 9), status: 201);
  }
  if (request.method == 'PUT') {
    final estado = request.body.contains('CUMPLIDA') ? 'CUMPLIDA' : 'ANULADA';
    return jsonResponse(sancionJson(estado: estado));
  }
  if (request.url.path == '/api/sanciones/1') {
    return jsonResponse(sancionJson());
  }
  final cumplida = sancionJson(
    id: 2,
    estado: 'CUMPLIDA',
    inicio: '2020-01-01',
    fin: '2020-12-31',
    motivo: 'Retraso de ruta',
    nombres: 'María Conductor',
  );
  if (request.url.queryParameters['estado'] == 'CUMPLIDA') {
    return jsonResponse(<dynamic>[cumplida]);
  }
  return jsonResponse(<dynamic>[sancionJson(), cumplida]);
});

void main() {
  testWidgets('lista las sanciones con el token y de 20 en 20', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(mock.lastRequest.url.path, '/api/sanciones');
    expect(mock.lastRequest.headers['authorization'], 'Bearer jwt');
    expect(mock.lastQuery['pageSize'], '20');
    expect(find.text('Sanción #1'), findsOneWidget);
    expect(find.text('Sanción #2'), findsOneWidget);
    expect(find.text('ACTIVA'), findsOneWidget);
    expect(find.text('CUMPLIDA'), findsOneWidget);
    expect(find.text('Luis Conductor · 1712345678'), findsOneWidget);
    expect(find.text('Conducción temeraria'), findsOneWidget);
    expect(find.text('VIGENTE'), findsOneWidget);
  });

  testWidgets('filtra por conductor y por estado', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.enterText(find.byType(TextField).first, '1712345678');
    await tester.tap(find.text('Buscar'));
    await cargar(tester);
    expect(mock.lastQuery['conductor'], '1712345678');

    await tester.tap(find.text('Cumplidas'));
    await cargar(tester);
    expect(mock.lastQuery['estado'], 'CUMPLIDA');
    expect(mock.lastQuery['conductor'], '1712345678');
    expect(find.text('Sanción #1'), findsNothing);
    expect(find.text('Retraso de ruta'), findsOneWidget);

    await tester.tap(find.text('Todas'));
    await cargar(tester);
    expect(mock.lastQuery.containsKey('estado'), isFalse);
  });

  testWidgets('al tocar la tarjeta consulta el detalle', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Sanción #1'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.url.path, '/api/sanciones/1');
    expect(find.text('Conductor'), findsNWidgets(2));
    expect(find.text('Motivo'), findsOneWidget);
    expect(find.text('Fecha de inicio'), findsOneWidget);
    expect(find.text('Fecha de registro'), findsOneWidget);
    expect(find.text('Marcar cumplida'), findsOneWidget);
    expect(find.text('Anular sanción'), findsOneWidget);
  });

  testWidgets('marcar cumplida envía el PUT con el nuevo estado', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Sanción #1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar cumplida'));
    await tester.pumpAndSettle();

    expect(find.text('Marcar como cumplida'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Marcar cumplida'));
    await tester.pumpAndSettle();

    final envio = mock.ultimaCon('PUT');
    expect(envio.url.path, '/api/sanciones/1');
    final body = mock.jsonBody(envio);
    expect(body['estado'], 'CUMPLIDA');
    expect(body['motivo'], 'Conducción temeraria');
    expect(body['fechaInicio'], '2000-01-01');
    expect(body['fechaFin'], '2099-12-31');
    expect(body.containsKey('identificacionConductor'), isFalse);
    expect(
      find.text('La sanción ya fue cumplida; no bloquea planillas.'),
      findsOneWidget,
    );
    expect(find.text('Marcar cumplida'), findsNothing);
  });

  testWidgets('anular envía el PUT con el estado ANULADA', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Sanción #1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anular sanción'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Anular'));
    await tester.pumpAndSettle();

    final envio = mock.ultimaCon('PUT');
    expect(mock.jsonBody(envio)['estado'], 'ANULADA');
    expect(
      find.text('La sanción fue anulada; no bloquea planillas.'),
      findsOneWidget,
    );
  });

  testWidgets('una sanción cumplida no ofrece cambiar de estado', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Sanción #2'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.url.path, '/api/sanciones/2');
    expect(find.text('Anular sanción'), findsNothing);
    expect(find.text('Marcar cumplida'), findsNothing);
    expect(mock.requests.where((request) => request.method == 'PUT'), isEmpty);
  });

  testWidgets('un error del backend se muestra tal cual', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Forbidden',
        'detail': 'Acceso denegado.',
      }, status: 403),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('No se pudieron cargar las sanciones'), findsOneWidget);
    expect(find.text('Acceso denegado.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('sin sanciones muestra el estado vacío', (tester) async {
    final mock = MockApi((_) => jsonResponse(<dynamic>[]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Sin sanciones'), findsOneWidget);
    expect(find.text('No hay sanciones para estos filtros.'), findsOneWidget);
    expect(find.text('Limpiar filtros'), findsOneWidget);
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

    await tester.tap(find.byTooltip('Nueva sanción'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Conductor').last,
      '1712345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo'),
      'Reiteración de retrasos',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar sanción'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/sanciones');
    expect(mock.jsonBody(post), <String, dynamic>{
      'identificacionConductor': '1712345678',
      'motivo': 'Reiteración de retrasos',
    });

    expect(find.text('Sanción #9 registrada.'), findsOneWidget);
    expect(mock.lastRequest.method, 'GET');
    expect(find.text('Registrar sanción'), findsNothing);
  });

  testWidgets('no desborda en una pantalla de 320x640', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Sanción #1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
