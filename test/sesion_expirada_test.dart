import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/services/remote/api_service.dart';
import 'package:sitramix/utils/sesion_expirada.dart';

import 'helpers/almacenamiento_falso.dart';

Widget appCon({
  required ApiException error,
  required AlmacenamientoFalso almacenamiento,
  required List<String> eventos,
  Map<String, WidgetBuilder>? rutas,
}) => MaterialApp(
  routes: rutas ?? const <String, WidgetBuilder>{},
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final atendida = await cerrarSesionSiExpirada(
              context,
              error,
              storage: almacenamiento,
              irAlLogin: rutas == null ? (_) => eventos.add('login') : null,
            );
            eventos.add('resultado:$atendida');
          },
          child: const Text('Provocar error'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('un 401 borra la sesión y vuelve al login', (tester) async {
    final almacenamiento = AlmacenamientoFalso();
    final eventos = <String>[];

    await tester.pumpWidget(
      appCon(
        error: const ApiException('Unauthorized', statusCode: 401),
        almacenamiento: almacenamiento,
        eventos: eventos,
      ),
    );
    await tester.tap(find.text('Provocar error'));
    await tester.pumpAndSettle();

    expect(almacenamiento.limpiezas, 1);
    expect(almacenamiento.token, isNull);
    expect(eventos, <String>['login', 'resultado:true']);
    expect(find.text(mensajeSesionExpirada), findsOneWidget);
  });

  testWidgets('navega al login con las rutas de la app', (tester) async {
    final almacenamiento = AlmacenamientoFalso();
    final eventos = <String>[];

    await tester.pumpWidget(
      appCon(
        error: const ApiException('Unauthorized', statusCode: 401),
        almacenamiento: almacenamiento,
        eventos: eventos,
        rutas: <String, WidgetBuilder>{
          '/login': (_) => const Scaffold(body: Text('Pantalla de login')),
        },
      ),
    );
    await tester.tap(find.text('Provocar error'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de login'), findsOneWidget);
    expect(find.text('Provocar error'), findsNothing);
    expect(find.text(mensajeSesionExpirada), findsOneWidget);
  });

  testWidgets('un 403 no cierra la sesión', (tester) async {
    final almacenamiento = AlmacenamientoFalso();
    final eventos = <String>[];

    await tester.pumpWidget(
      appCon(
        error: const ApiException('Forbidden', statusCode: 403),
        almacenamiento: almacenamiento,
        eventos: eventos,
      ),
    );
    await tester.tap(find.text('Provocar error'));
    await tester.pumpAndSettle();

    expect(almacenamiento.limpiezas, 0);
    expect(eventos, <String>['resultado:false']);
  });

  testWidgets('un fallo de red no cierra la sesión', (tester) async {
    final almacenamiento = AlmacenamientoFalso();
    final eventos = <String>[];

    await tester.pumpWidget(
      appCon(
        error: const ApiException('Sin conexión'),
        almacenamiento: almacenamiento,
        eventos: eventos,
      ),
    );
    await tester.tap(find.text('Provocar error'));
    await tester.pumpAndSettle();

    expect(almacenamiento.limpiezas, 0);
    expect(eventos, <String>['resultado:false']);
    expect(find.text(mensajeSesionExpirada), findsNothing);
  });
}
