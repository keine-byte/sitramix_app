import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/screens/pagos_screen.dart';
import 'package:sitramix/services/remote/pagos_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> pagoJson({
  int? id = 1,
  int planilla = 1,
  double valor = 4000,
  String? fechaPago = '2026-10-26',
}) => <String, dynamic>{
  'id': id,
  'numeroPlanilla': planilla,
  'valorPagado': valor,
  'fechaPago': fechaPago,
  'registradoPor': 'asistente.bruno',
  'fechaRegistro': '2026-10-26T09:30:00-05:00',
};

Widget appCon(MockApi mock) => MaterialApp(
  home: PagosScreen(
    api: PagosApi(api: mock.createService(), token: 'jwt'),
  ),
);

Future<void> cargar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

MockApi backend() => MockApi((request) {
  if (request.url.path == '/api/pagos/1') return jsonResponse(pagoJson());
  return jsonResponse(<dynamic>[
    pagoJson(),
    pagoJson(id: 2, planilla: 2, valor: 12500.5),
  ]);
});

String primeroDelMes() {
  final hoy = DateTime.now();
  final mes = hoy.month.toString().padLeft(2, '0');
  return '${hoy.year}-$mes-01';
}

void main() {
  testWidgets('lista los pagos con el token y de 20 en 20', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(mock.lastRequest.url.path, '/api/pagos');
    expect(mock.lastRequest.headers['authorization'], 'Bearer jwt');
    expect(mock.lastQuery['page'], '1');
    expect(mock.lastQuery['pageSize'], '20');
    expect(find.text('Pago #1'), findsOneWidget);
    expect(find.text('Pago #2'), findsOneWidget);
    expect(find.text('\$ 4.000'), findsOneWidget);
    expect(find.text('\$ 12.500,50'), findsOneWidget);
    expect(find.text('Planilla 1'), findsOneWidget);
    expect(find.text('Fecha de pago 26/10/2026'), findsNWidgets(2));
    expect(find.text('Registró asistente.bruno'), findsNWidgets(2));
  });

  testWidgets('busca por placa y número de planilla', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vehículo'),
      'BRU001',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Planilla'), '7');
    await tester.tap(find.text('Buscar'));
    await cargar(tester);

    expect(mock.lastQuery['placa'], 'BRU001');
    expect(mock.lastQuery['numeroPlanilla'], '7');
  });

  testWidgets('el rango de fechas se envía como desde y hasta', (tester) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Desde'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(mock.lastQuery['desde'], primeroDelMes());
    expect(mock.lastQuery.containsKey('hasta'), isFalse);

    await tester.tap(find.text('Quitar fechas'));
    await cargar(tester);

    expect(mock.lastQuery.containsKey('desde'), isFalse);
    expect(find.text('Quitar fechas'), findsNothing);
  });

  testWidgets('al tocar la tarjeta consulta el detalle del pago', (
    tester,
  ) async {
    final mock = backend();

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    await tester.tap(find.text('Pago #1'));
    await tester.pumpAndSettle();

    expect(mock.lastRequest.url.path, '/api/pagos/1');
    expect(find.text('Valor pagado'), findsOneWidget);
    expect(find.text('\$ 4.000'), findsWidgets);
    expect(find.text('Fecha de pago'), findsOneWidget);
    expect(find.text('Registrado por'), findsOneWidget);
    expect(find.text('Fecha de registro'), findsOneWidget);
  });

  testWidgets('sin pagos muestra el estado vacío', (tester) async {
    final mock = MockApi((_) => jsonResponse(<dynamic>[]));

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('Sin pagos'), findsOneWidget);
    expect(find.text('No hay pagos para estos filtros.'), findsOneWidget);
  });

  testWidgets('un error del backend se muestra tal cual', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Forbidden',
        'detail': 'No tienes permisos para ver pagos.',
      }, status: 403),
    );

    await tester.pumpWidget(appCon(mock));
    await cargar(tester);

    expect(find.text('No se pudieron cargar los pagos'), findsOneWidget);
    expect(find.text('No tienes permisos para ver pagos.'), findsOneWidget);
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

    expect(find.text('Pago #1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
