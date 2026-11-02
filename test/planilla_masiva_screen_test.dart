import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/screens/planilla_masiva_screen.dart';
import 'package:sitramix/services/remote/planillas_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> planillaJson({int numero = 21, String placa = 'BRU001'}) =>
    <String, dynamic>{
      'numero': numero,
      'fecha': '2026-10-29',
      'hora': '08:30:00',
      'placaVehiculo': placa,
      'tipo': 'VIAJE',
      'estado': 'ACTIVA',
      'tarifaId': 3,
      'valorPagado': 17000,
      'estadoPago': 'PENDIENTE',
    };

Map<String, dynamic> informeJson({
  int solicitadas = 2,
  int registradas = 1,
  int rechazadas = 1,
  List<dynamic>? correctas,
  List<dynamic>? rechazos,
}) => <String, dynamic>{
  'totalSolicitadas': solicitadas,
  'totalRegistradas': registradas,
  'totalRechazadas': rechazadas,
  'correctas': correctas ?? <dynamic>[planillaJson()],
  'rechazadas':
      rechazos ??
      <dynamic>[
        <String, dynamic>{
          'placaVehiculo': 'BRU002',
          'codigo': 409,
          'motivo': 'El conductor tiene una sanción ACTIVA.',
        },
      ],
};

Widget appCon(MockApi mock) => MaterialApp(
  home: PlanillaMasivaScreen(
    api: PlanillasApi(api: mock.createService(), token: 'jwt'),
  ),
);

String primeroDelMes() {
  final hoy = DateTime.now();
  final mes = hoy.month.toString().padLeft(2, '0');
  return '${hoy.year}-$mes-01';
}

Future<void> elegirFecha(WidgetTester tester) async {
  await tester.tap(find.text('Elegir fecha'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('1').last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> agregarPlaca(WidgetTester tester, String placa) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Placa'), placa);
  await tester.tap(find.text('Agregar'));
  await tester.pump();
}

void main() {
  testWidgets('registra el lote con fecha, placas, tipo y tarifa', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(informeJson()));

    await tester.pumpWidget(appCon(mock));
    await elegirFecha(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tarifa (ID)'),
      '3',
    );
    await agregarPlaca(tester, 'bru001');
    await agregarPlaca(tester, 'BRU002');

    expect(find.widgetWithText(InputChip, 'BRU001'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'BRU002'), findsOneWidget);

    await tester.tap(find.text('Registrar planillas'));
    await tester.pumpAndSettle();

    final envio = mock.ultimaCon('POST');
    expect(envio.url.path, '/api/planillas/masivas');
    expect(envio.headers['authorization'], 'Bearer jwt');
    expect(mock.jsonBody(envio), <String, dynamic>{
      'fecha': primeroDelMes(),
      'placasVehiculos': <String>['BRU001', 'BRU002'],
      'tipo': 'VIAJE',
      'tarifaId': 3,
    });

    expect(find.text('Informe de la carga'), findsOneWidget);
    expect(find.text('Solicitadas'), findsOneWidget);
    expect(find.text('Registradas'), findsOneWidget);
    expect(find.text('Rechazadas'), findsOneWidget);
    expect(find.text('#21 · BRU001'), findsOneWidget);
    expect(
      find.text('BRU002 · 409 · El conductor tiene una sanción ACTIVA.'),
      findsOneWidget,
    );
    expect(
      find.text('Los totales no cuadran: revisa las planillas registradas.'),
      findsNothing,
    );
  });

  testWidgets('normaliza la placa y evita repetirla', (tester) async {
    final mock = MockApi((_) => jsonResponse(informeJson()));

    await tester.pumpWidget(appCon(mock));
    expect(find.text('Aún no agregas placas.'), findsOneWidget);

    await agregarPlaca(tester, 'bru001');
    expect(find.widgetWithText(InputChip, 'BRU001'), findsOneWidget);
    expect(find.text('Aún no agregas placas.'), findsNothing);

    await agregarPlaca(tester, 'BRU001');
    expect(find.text('Esa placa ya está en la lista.'), findsOneWidget);
    expect(find.byType(InputChip), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar BRU001'));
    await tester.pump();

    expect(find.byType(InputChip), findsNothing);
    expect(find.text('Aún no agregas placas.'), findsOneWidget);
    expect(mock.requests, isEmpty);
  });

  testWidgets('valida la fecha, las placas y la tarifa antes de enviar', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(informeJson()));

    await tester.pumpWidget(appCon(mock));

    await tester.tap(find.text('Registrar planillas'));
    await tester.pump();
    expect(find.text('Elige la fecha de las planillas.'), findsOneWidget);

    await elegirFecha(tester);
    expect(find.text('Elige la fecha de las planillas.'), findsNothing);

    await tester.tap(find.text('Registrar planillas'));
    await tester.pump();
    expect(find.text('Agrega al menos una placa.'), findsOneWidget);

    await agregarPlaca(tester, 'BRU001');
    expect(find.text('Agrega al menos una placa.'), findsNothing);

    await tester.tap(find.text('Registrar planillas'));
    await tester.pump();
    expect(find.text('Escribe el ID de la tarifa (número).'), findsOneWidget);

    expect(mock.requests.where((request) => request.method == 'POST'), isEmpty);
  });

  testWidgets('avisa cuando los totales del informe no cuadran', (
    tester,
  ) async {
    final mock = MockApi(
      (_) => jsonResponse(informeJson(solicitadas: 3, registradas: 1)),
    );

    await tester.pumpWidget(appCon(mock));
    await elegirFecha(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tarifa (ID)'),
      '3',
    );
    await agregarPlaca(tester, 'BRU001');

    await tester.tap(find.text('Registrar planillas'));
    await tester.pumpAndSettle();

    expect(
      find.text('Los totales no cuadran: revisa las planillas registradas.'),
      findsOneWidget,
    );
  });

  testWidgets('un 400 del lote se muestra tal cual', (tester) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Bad Request',
        'detail': 'Una solicitud mal formada retorna 400.',
      }, status: 400),
    );

    await tester.pumpWidget(appCon(mock));
    await elegirFecha(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tarifa (ID)'),
      '3',
    );
    await agregarPlaca(tester, 'BRU001');

    await tester.tap(find.text('Registrar planillas'));
    await tester.pumpAndSettle();

    expect(find.text('Una solicitud mal formada retorna 400.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Informe de la carga'), findsNothing);
  });

  testWidgets('no desborda en una pantalla de 320x640', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mock = MockApi((_) => jsonResponse(informeJson()));

    await tester.pumpWidget(appCon(mock));
    await elegirFecha(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tarifa (ID)'),
      '3',
    );
    await agregarPlaca(tester, 'BRU001');

    await tester.ensureVisible(find.text('Registrar planillas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar planillas'));
    await tester.pumpAndSettle();

    expect(find.text('Informe de la carga'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un 401 cierra la sesión y vuelve al login', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
        home: PlanillaMasivaScreen(
          api: PlanillasApi(api: mock.createService(), token: 'jwt'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await elegirFecha(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tarifa (ID)'),
      '3',
    );
    await agregarPlaca(tester, 'BRU001');

    await tester.tap(find.text('Registrar planillas'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de login'), findsOneWidget);
    expect(
      find.text('Tu sesión expiró. Vuelve a iniciar sesión.'),
      findsOneWidget,
    );
  });
}
