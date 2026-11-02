import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/screens/afiliaciones_screen.dart';
import 'package:sitramix/services/remote/afiliaciones_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> afiliacionJson({
  int? id = 7,
  String asociado = '1001',
  String placa = 'BRU001',
  String estado = 'ACTIVA',
  String? fechaFin,
}) => <String, dynamic>{
  'id': id,
  'identificacionAsociado': asociado,
  'placaVehiculo': placa,
  'fechaAfiliacion': '2026-01-01',
  'fechaFinAfiliacion': fechaFin,
  'estado': estado,
  'fechaRegistro': '2026-01-01',
  'ultimaActualizacion': '2026-01-02',
};

Widget appCon(MockApi mock) => MaterialApp(
  home: AfiliacionesScreen(
    api: AfiliacionesApi(api: mock.createService(), token: 'jwt'),
  ),
);

Future<void> cargar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

MockApi backend() => MockApi((request) {
  if (request.method == 'DELETE') {
    return jsonResponse(
      afiliacionJson(estado: 'FINALIZADA', fechaFin: '2026-10-29'),
    );
  }
  if (request.url.path == '/api/afiliaciones/7') {
    return jsonResponse(afiliacionJson());
  }
  final estado = request.url.queryParameters['estado'] ?? 'ACTIVA';
  return jsonResponse(<dynamic>[afiliacionJson(estado: estado)]);
});

void main() {
  testWidgets('lista las afiliaciones con el token de la sesión', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Afiliación #7'), findsOneWidget);
    expect(find.text('ACTIVA'), findsOneWidget);
    expect(find.text('1001'), findsOneWidget);
    expect(find.text('BRU001'), findsOneWidget);
    expect(find.text('Desde 01/01/2026'), findsOneWidget);
    expect(find.text('Hasta 29/10/2026'), findsNothing);
    expect(mock.lastRequest.headers['authorization'], 'Bearer jwt');
    expect(mock.lastQuery['page'], '1');
    expect(mock.lastQuery['pageSize'], '20');
    expect(mock.lastQuery.containsKey('estado'), isFalse);
  });

  testWidgets('una afiliación finalizada muestra su fecha de fin', (
    tester,
  ) async {
    final mock = MockApi(
      (_) => jsonResponse(<dynamic>[
        afiliacionJson(estado: 'FINALIZADA', fechaFin: '2026-10-29'),
      ]),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('FINALIZADA'), findsOneWidget);
    expect(find.text('Hasta 29/10/2026'), findsOneWidget);
  });

  testWidgets('la búsqueda envía asociado y vehículo', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.enterText(find.byType(TextFormField).first, '1001');
    await tester.enterText(find.byType(TextFormField).last, 'BRU');
    await tester.tap(find.widgetWithText(TextButton, 'Buscar'));
    await cargar(tester);

    expect(mock.lastQuery['asociado'], '1001');
    expect(mock.lastQuery['vehiculo'], 'BRU');
  });

  testWidgets('los chips envían el estado', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Finalizadas'));
    await cargar(tester);

    expect(mock.lastQuery['estado'], 'FINALIZADA');
    expect(find.text('FINALIZADA'), findsOneWidget);
  });

  testWidgets('sin resultados muestra el estado vacío', (tester) async {
    final mock = MockApi((_) => jsonResponse(<dynamic>[]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Sin afiliaciones'), findsOneWidget);
    expect(find.text('Limpiar filtros'), findsOneWidget);
  });
  testWidgets('al tocar la tarjeta consulta el detalle de la afiliación', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Afiliación #7'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.url.path, '/api/afiliaciones/7');
    expect(find.text('Fecha de afiliación'), findsOneWidget);
    expect(find.text('Fecha de fin'), findsOneWidget);
    expect(find.text('Vigente'), findsOneWidget);
    expect(find.text('Fecha de registro'), findsOneWidget);
    expect(find.text('Última actualización'), findsOneWidget);
    expect(find.text('Finalizar afiliación'), findsOneWidget);
  });

  testWidgets('finalizar envía el DELETE y deja la afiliación finalizada', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Afiliación #7'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Finalizar afiliación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar afiliación'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Finalizar'));
    await tester.pumpAndSettle();

    final borrado = mock.ultimaCon('DELETE');
    expect(borrado.url.path, '/api/afiliaciones/7');
    expect(mock.jsonBody(borrado), <String, dynamic>{
      'fechaFinAfiliacion': null,
    });
    expect(find.text('La afiliación ya está finalizada.'), findsOneWidget);
    expect(find.text('Finalizar afiliación'), findsNothing);
  });

  testWidgets('un error del backend se muestra tal cual', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Forbidden',
        'detail': 'No tienes permisos para ver afiliaciones.',
      }, status: 403),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('No se pudieron cargar las afiliaciones'), findsOneWidget);
    expect(
      find.text('No tienes permisos para ver afiliaciones.'),
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

    expect(find.text('Afiliación #7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
