import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/models/vehiculo/vehiculo.dart';
import 'package:sitramix/screens/formulario_vehiculo_screen.dart';
import 'package:sitramix/services/remote/vehiculos_api.dart';

import 'helpers/mock_api.dart';

Map<String, dynamic> vehiculoJson({
  String placa = 'BRU001',
  String tipo = 'BUSETA',
  bool activo = true,
  String? vigenciaSoat = '2030-12-31',
  int? tarifaId = 51,
  String? identificacionConductor = '9900000002',
}) => <String, dynamic>{
  'placa': placa,
  'tipo': tipo,
  'marca': 'Chevrolet',
  'modelo': '2025',
  'capacidadPasajeros': 10,
  'tarjetaPropiedad': 'TP-BRU001',
  'activo': activo,
  'tarifaId': ?tarifaId,
  'tarifa': <String, dynamic>{'id': 51, 'total': 4000},
  'vigenciaSoat': ?vigenciaSoat,
  'vigenciaTrm': '2030-12-31',
  'fechaIngreso': '2026-01-01',
  'identificacionConductor': ?identificacionConductor,
};

Vehiculo vehiculoDePrueba() => Vehiculo(
  placa: 'BRU001',
  tipo: 'BUSETA',
  marca: 'Chevrolet',
  modelo: '2025',
  capacidadPasajeros: 10,
  tarjetaPropiedad: 'TP-BRU001',
  activo: true,
  tarifaId: 51,
  vigenciaSoat: DateTime(2030, 12, 31),
  vigenciaTrm: DateTime(2030, 12, 31),
  fechaIngreso: DateTime(2026, 1, 1),
  identificacionConductor: '9900000002',
);

Widget appCon(
  MockApi mock, {
  Vehiculo? vehiculo,
  void Function(Vehiculo?) onResultado = _sinResultado,
}) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final resultado = await Navigator.of(context).push<Vehiculo>(
              MaterialPageRoute<Vehiculo>(
                builder: (_) => FormularioVehiculoScreen(
                  api: VehiculosApi(api: mock.createService(), token: 'jwt'),
                  vehiculo: vehiculo,
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

void _sinResultado(Vehiculo? resultado) {}

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

Future<void> llenarAlta(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Placa'), 'bru001');
  await tester.enterText(find.widgetWithText(TextFormField, 'Tipo'), 'BUSETA');
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Marca'),
    'Chevrolet',
  );
  await tester.enterText(find.widgetWithText(TextFormField, 'Modelo'), '2025');
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Capacidad de pasajeros'),
    '10',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Tarjeta de propiedad'),
    'TP-BRU001',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Tarifa (ID)'),
    '51',
  );
}

void main() {
  testWidgets('el alta envía POST y devuelve el vehículo guardado', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(vehiculoJson(), status: 201));
    Vehiculo? guardado;

    await tester.pumpWidget(
      appCon(mock, onResultado: (resultado) => guardado = resultado),
    );
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar vehículo'));
    await tester.pumpAndSettle();

    final post = mock.ultimaCon('POST');
    expect(post.url.path, '/api/vehiculos');
    expect(post.headers['authorization'], 'Bearer jwt');
    expect(mock.jsonBody(post), <String, dynamic>{
      'placa': 'BRU001',
      'tipo': 'BUSETA',
      'marca': 'Chevrolet',
      'modelo': '2025',
      'capacidadPasajeros': 10,
      'tarjetaPropiedad': 'TP-BRU001',
      'activo': true,
      'tarifaId': 51,
    });
    expect(guardado?.placa, 'BRU001');
  });

  testWidgets('sin los datos del vehículo no se envía nada', (tester) async {
    final mock = MockApi((_) => jsonResponse(vehiculoJson(), status: 201));

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar vehículo'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe la placa.'), findsOneWidget);
    expect(find.text('Escribe el tipo de vehículo.'), findsOneWidget);
    expect(find.text('Escribe la capacidad de pasajeros.'), findsOneWidget);
    expect(mock.requests, isEmpty);
  });

  testWidgets('la edición envía solo los seis campos que admite el PUT', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(vehiculoJson()));
    Vehiculo? guardado;

    await tester.pumpWidget(
      appCon(
        mock,
        vehiculo: vehiculoDePrueba(),
        onResultado: (resultado) => guardado = resultado,
      ),
    );
    await abrir(tester);

    expect(find.text('Editar vehículo'), findsWidgets);

    final placa = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Placa'),
    );
    expect(placa.enabled, isFalse);
    final capacidad = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Capacidad de pasajeros'),
    );
    expect(capacidad.enabled, isFalse);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tarifa (ID)'),
      '77',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Identificación del conductor'),
      '9900000003',
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await tester.pumpAndSettle();

    final put = mock.ultimaCon('PUT');
    expect(put.url.path, '/api/vehiculos/BRU001');
    expect(mock.jsonBody(put), <String, dynamic>{
      'identificacionConductor': '9900000003',
      'activo': false,
      'vigenciaSoat': '2030-12-31',
      'vigenciaTrm': '2030-12-31',
      'fechaIngreso': '2026-01-01',
      'tarifaId': 77,
    });
    expect(guardado?.placa, 'BRU001');
  });

  testWidgets('una fecha de vigencia vacía se omite del cuerpo', (
    tester,
  ) async {
    final mock = MockApi((_) => jsonResponse(vehiculoJson(), status: 201));

    await tester.pumpWidget(
      appCon(
        mock,
        vehiculo: Vehiculo(
          placa: 'BRU001',
          tipo: 'BUSETA',
          marca: 'Chevrolet',
          modelo: '2025',
          capacidadPasajeros: 10,
          tarjetaPropiedad: 'TP-BRU001',
          activo: true,
        ),
      ),
    );
    await abrir(tester);

    expect(find.text('Sin fecha'), findsNWidgets(3));

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await tester.pumpAndSettle();

    final cuerpo = mock.jsonBody(mock.ultimaCon('PUT'));
    expect(cuerpo, <String, dynamic>{'activo': true});
  });

  testWidgets('un error del backend se muestra dentro del formulario', (
    tester,
  ) async {
    final mock = MockApi(
      (_) => jsonResponse(<String, dynamic>{
        'title': 'Conflict',
        'detail': 'La placa ya está registrada.',
      }, status: 409),
    );

    await tester.pumpWidget(appCon(mock));
    await abrir(tester);

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar vehículo'));
    await tester.pumpAndSettle();

    expect(find.text('La placa ya está registrada.'), findsOneWidget);
    expect(find.byType(FormularioVehiculoScreen), findsOneWidget);
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
        home: FormularioVehiculoScreen(
          api: VehiculosApi(api: mock.createService(), token: 'jwt'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await llenarAlta(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar vehículo'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de login'), findsOneWidget);
    expect(
      find.text('Tu sesión expiró. Vuelve a iniciar sesión.'),
      findsOneWidget,
    );
  });
}
