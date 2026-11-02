import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/models/resumen/resumen_dashboard.dart';
import 'package:sitramix/models/sesion/sesion.dart';
import 'package:sitramix/screens/inicio_screen.dart';

const resumenFalso = ResumenDashboard(
  asociados: 48,
  afiliaciones: 12,
  conductores: 74,
  sanciones: 3,
  vehiculos: 87,
  tarifas: 6,
  planillas: 32,
  despachos: 15,
  pagos: 21,
  mantenimientos: 9,
);

const resumenLleno = ResumenDashboard(
  asociados: 100,
  conductores: 100,
  vehiculos: 100,
  sanciones: 100,
);

Future<ResumenDashboard> cargarResumenFalso(Sesion _) async => resumenFalso;

Future<ResumenDashboard> cargarResumenQueFalla(Sesion _) async =>
    throw Exception('sin red');

Widget appCon(
  Sesion? sesion, {
  Future<ResumenDashboard> Function(Sesion)? cargarResumen = cargarResumenFalso,
}) => MaterialApp(
  home: InicioScreen(sesionInicial: sesion, cargarResumen: cargarResumen),
  onGenerateRoute: (_) => MaterialPageRoute<void>(
    builder: (_) => const Scaffold(body: Text('pantalla de login')),
  ),
);

Finder modulo(String id) => find.byKey(ValueKey('modulo-$id'));
Finder nav(String id) => find.byKey(ValueKey('nav-$id'));
Finder stat(String id) => find.byKey(ValueKey('stat-$id'));

void main() {
  testWidgets('el dashboard del GERENTE muestra el resumen y los módulos', (
    tester,
  ) async {
    await tester.pumpWidget(
      appCon(const Sesion(token: 'jwt', rol: Rol.gerente, nombres: 'Ana')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido,'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('GERENTE'), findsOneWidget);
    expect(find.text('GESTIÓN'), findsOneWidget);

    final logo = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(logo.width, 24);

    expect(stat('asociados'), findsOneWidget);
    expect(stat('conductores'), findsOneWidget);
    expect(stat('vehiculos'), findsOneWidget);
    expect(stat('sanciones'), findsOneWidget);
    expect(find.text('48'), findsWidgets);
    expect(find.text('74'), findsWidgets);
    expect(find.text('87'), findsWidgets);

    for (final id in <String>[
      'asociados',
      'afiliaciones',
      'conductores',
      'sanciones',
      'vehiculos',
      'tarifas',
      'planillas',
      'despachos',
      'pagos',
      'mantenimientos',
    ]) {
      expect(modulo(id), findsOneWidget, reason: 'falta el módulo $id');
    }

    expect(nav('inicio'), findsOneWidget);
    expect(nav('vehiculos'), findsOneWidget);
    expect(nav('planillas'), findsOneWidget);
    expect(nav('perfil'), findsOneWidget);
  });

  testWidgets('un ASISTENTE no ve Tarifas', (tester) async {
    await tester.pumpWidget(
      appCon(const Sesion(token: 'jwt', rol: Rol.asistente, nombres: 'Bea')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ASISTENTE'), findsOneWidget);
    expect(modulo('asociados'), findsOneWidget);
    expect(modulo('tarifas'), findsNothing);
  });

  testWidgets('un ASOCIADO solo ve Mi cuenta', (tester) async {
    await tester.pumpWidget(
      appCon(
        const Sesion(token: 'jwt', rol: Rol.asociado, username: 'asociado1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('asociado1'), findsOneWidget);
    expect(find.text('ASOCIADO'), findsOneWidget);
    expect(modulo('mi-cuenta'), findsOneWidget);
    expect(modulo('asociados'), findsNothing);
    expect(modulo('planillas'), findsNothing);
    expect(stat('asociados'), findsNothing);
    expect(nav('mi-cuenta'), findsOneWidget);
  });

  testWidgets('sin sesión no ofrece módulos', (tester) async {
    await tester.pumpWidget(appCon(null));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido,'), findsOneWidget);
    expect(find.text('Invitado'), findsOneWidget);
    expect(find.text('SIN SESIÓN'), findsOneWidget);
    expect(modulo('asociados'), findsNothing);
    expect(modulo('mi-cuenta'), findsNothing);
    expect(stat('asociados'), findsNothing);
  });

  testWidgets('sin nombre en la API saluda con el rol, no con el documento', (
    tester,
  ) async {
    await tester.pumpWidget(
      appCon(
        const Sesion(
          token: 'jwt',
          rol: Rol.gerente,
          identificacion: '1101812715',
          username: '1101812715',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido,'), findsOneWidget);
    expect(find.text('Gerente'), findsOneWidget);
    expect(find.text('GERENTE'), findsOneWidget);
    expect(find.text('1101812715'), findsNothing);
  });

  testWidgets('el perfil muestra el nombre y la empresa de la sesión', (
    tester,
  ) async {
    await tester.pumpWidget(
      appCon(
        const Sesion(
          token: 'jwt',
          rol: Rol.gerente,
          nombres: 'Ana',
          identificacion: '1101812715',
          empresa: 'TRANSPOMIX',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(nav('perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Ana'), findsWidgets);
    expect(find.text('Empresa'), findsOneWidget);
    expect(find.text('TRANSPOMIX'), findsOneWidget);
  });

  testWidgets('si la API falla los contadores quedan en guiones', (
    tester,
  ) async {
    await tester.pumpWidget(
      appCon(
        const Sesion(token: 'jwt', rol: Rol.gerente, nombres: 'Ana'),
        cargarResumen: cargarResumenQueFalla,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('—'), findsWidgets);
    expect(modulo('asociados'), findsOneWidget);
  });

  testWidgets('una página llena se muestra como 100+', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InicioScreen(
          sesionInicial: const Sesion(
            token: 'jwt',
            rol: Rol.gerente,
            nombres: 'Ana',
          ),
          cargarResumen: (_) async => resumenLleno,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('100+'), findsWidgets);
    expect(find.text('100'), findsNothing);
  });

  testWidgets('el dashboard no desborda en una pantalla de 320x640', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      appCon(const Sesion(token: 'jwt', rol: Rol.gerente, nombres: 'Ana')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(modulo('asociados'), findsOneWidget);
    expect(nav('perfil'), findsOneWidget);
  });

  testWidgets('la barra inferior abre el perfil y cierra la sesión', (
    tester,
  ) async {
    await tester.pumpWidget(
      appCon(const Sesion(token: 'jwt', rol: Rol.gerente, nombres: 'Ana')),
    );
    await tester.pumpAndSettle();

    await tester.tap(nav('perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Sesión activa en este dispositivo.'), findsOneWidget);
    expect(find.byKey(const ValueKey('perfil-cerrar-sesion')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('perfil-cerrar-sesion')));
    await tester.pumpAndSettle();

    expect(find.text('pantalla de login'), findsOneWidget);
  });
}
