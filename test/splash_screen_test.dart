import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/main.dart';
import 'package:sitramix/routes/app_routes.dart';
import 'package:sitramix/screens/splash_screen.dart';
import 'package:sitramix/widgets/marca_sitramix.dart';

Widget appCon({required String rutaSiguiente, Duration? duracion}) =>
    MaterialApp(
      home: SplashScreen(
        rutaSiguiente: rutaSiguiente,
        duracion: duracion ?? const Duration(milliseconds: 900),
      ),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: Text('pantalla ${settings.name}')),
      ),
    );

void main() {
  testWidgets('muestra la marca, el lema y la versión', (tester) async {
    await tester.pumpWidget(
      appCon(
        rutaSiguiente: AppRoutes.login,
        duracion: const Duration(hours: 1),
      ),
    );

    expect(find.text('SITRAMIX'), findsOneWidget);
    expect(find.text('SISTEMA DE TRANSPORTE MIXTO'), findsOneWidget);
    expect(find.text('v2.4.1 · Cooperativa SITRAMIX'), findsOneWidget);
    expect(find.byType(SitramixIcono), findsOneWidget);
    final icono = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(icono.width, 119);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entra sola al login cuando no hay sesión', (tester) async {
    await tester.pumpWidget(
      appCon(
        rutaSiguiente: AppRoutes.login,
        duracion: const Duration(milliseconds: 300),
      ),
    );

    expect(find.text('pantalla /login'), findsNothing);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('pantalla /login'), findsOneWidget);
  });

  testWidgets('entra a inicio con sesión y respeta el toque', (tester) async {
    await tester.pumpWidget(
      appCon(rutaSiguiente: AppRoutes.home, duracion: const Duration(hours: 1)),
    );

    await tester.tap(find.text('SITRAMIX'));
    await tester.pumpAndSettle();

    expect(find.text('pantalla /home'), findsOneWidget);
  });

  testWidgets('el toque no navega dos veces', (tester) async {
    await tester.pumpWidget(
      appCon(rutaSiguiente: AppRoutes.home, duracion: const Duration(hours: 1)),
    );

    await tester.tap(find.text('SITRAMIX'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(hours: 2));
    await tester.pumpAndSettle();

    expect(find.text('pantalla /home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la app arranca en el splash y llega al login', (tester) async {
    await tester.pumpWidget(const SitramixApp(mostrarSplash: true));

    expect(find.text('SISTEMA DE TRANSPORTE MIXTO'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('SISTEMA DE TRANSPORTE MIXTO'), findsNothing);
    expect(find.text('Iniciar sesión'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
