import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sitramix/models/sesion/sesion.dart';
import 'package:sitramix/routes/app_routes.dart';
import 'package:sitramix/screens/login_screen.dart';
import 'package:sitramix/services/remote/api_service.dart';
import 'package:sitramix/services/remote/login_service.dart';
import 'package:sitramix/services/remote/nombre_usuario_service.dart';
import 'package:sitramix/widgets/marca_sitramix.dart';

import 'helpers/almacenamiento_falso.dart';
import 'helpers/mock_api.dart';

Widget appCon(LoginService servicio, {AlmacenamientoFalso? almacenamiento}) =>
    MaterialApp(
      home: LoginScreen(
        servicio: servicio,
        almacenamiento: almacenamiento ?? AlmacenamientoFalso(),
      ),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: Text('pantalla ${settings.name}')),
      ),
    );

Map<String, Object?> sesionJson({
  String rol = 'GERENTE',
  bool requiereCambioPassword = false,
}) => <String, Object?>{
  'token': 'jwt-sitram',
  'rol': rol,
  'requiereCambioPassword': requiereCambioPassword,
  'nombres': 'María González',
};

Future<void> entrar(WidgetTester tester, String usuario, String clave) async {
  await tester.enterText(find.byKey(const ValueKey('login-usuario')), usuario);
  await tester.enterText(find.byKey(const ValueKey('login-password')), clave);
  await tester.tap(find.byKey(const ValueKey('login-enviar')));
  await tester.pumpAndSettle();
}

LoginService servicioFalso(Object? cuerpo, {int status = 200}) => LoginService(
  api: MockApi((_) => jsonResponse(cuerpo, status: status)).createService(),
);

Widget appConArgumentos(
  LoginService servicio, {
  required AlmacenamientoFalso almacenamiento,
  required NombreUsuarioService nombres,
  required void Function(Object? argumento) alEntrarAInicio,
}) => MaterialApp(
  home: LoginScreen(
    servicio: servicio,
    almacenamiento: almacenamiento,
    nombres: nombres,
  ),
  onGenerateRoute: (settings) {
    if (settings.name == AppRoutes.home) {
      alEntrarAInicio(settings.arguments);
    }
    return MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: Text('pantalla ${settings.name}')),
    );
  },
);

const Map<String, Object?> loginSinNombre = <String, Object?>{
  'token': 'jwt-sitram-nuevo',
  'tipo': 'Bearer',
  'expiraEn': 3600000,
  'identificacion': '1101812715',
  'username': '1101812715',
  'rol': 'GERENTE',
  'requiereCambioPassword': false,
  'empresa': <String, Object?>{
    'id': 8,
    'razonSocial': 'TRANSPOMIX',
    'nit': '1101812715',
  },
};

const Map<String, Object?> asociadoConNombre = <String, Object?>{
  'message': 'Recurso consultado correctamente.',
  'data': <String, Object?>{
    'identificacion': '1101812715',
    'nombres': 'Ana Pérez',
    'username': '1101812715',
    'activo': true,
  },
  'success': true,
};

void main() {
  testWidgets('muestra el encabezado y la hoja del prototipo', (tester) async {
    await tester.pumpWidget(appCon(servicioFalso(sesionJson())));

    expect(find.text('SITRAMIX'), findsOneWidget);
    expect(find.text('TRANSPORTE MIXTO'), findsOneWidget);
    expect(find.byType(SitramixChip), findsOneWidget);
    final logo = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(logo.width, 28);
    expect(find.text('Iniciar sesión'), findsNWidgets(2));
    expect(find.text('Ingresa con tu cuenta de cooperativa'), findsOneWidget);
    expect(find.text('USUARIO'), findsOneWidget);
    expect(find.text('CONTRASEÑA'), findsOneWidget);
    expect(find.text('¿Olvidé mi contraseña?'), findsOneWidget);
    expect(
      find.text('Sistema exclusivo para miembros de la Cooperativa'),
      findsOneWidget,
    );
  });

  testWidgets('valida los campos antes de llamar a la API', (tester) async {
    final mock = MockApi((_) => jsonResponse(sesionJson()));
    await tester.pumpWidget(appCon(LoginService(api: mock.createService())));

    await tester.tap(find.byKey(const ValueKey('login-enviar')));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu usuario.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
    expect(mock.requests, isEmpty);
  });

  testWidgets('envía username y password y entra a inicio', (tester) async {
    final mock = MockApi((_) => jsonResponse(sesionJson()));
    final almacenamiento = AlmacenamientoFalso();
    await tester.pumpWidget(
      appCon(
        LoginService(api: mock.createService()),
        almacenamiento: almacenamiento,
      ),
    );

    await entrar(tester, '  aperez ', 'clave123');

    final request = mock.ultimaCon('POST');
    expect(request.url.path, '/api/auth/login');
    expect(mock.jsonBody(request), {
      'username': 'aperez',
      'password': 'clave123',
    });
    expect(almacenamiento.sesionesGuardadas.single.rol, Rol.gerente);
    expect(find.text('pantalla /home'), findsOneWidget);
  });

  testWidgets('entrega la sesión recién creada a la pantalla de inicio', (
    tester,
  ) async {
    Object? argumento;
    final mock = MockApi((_) => jsonResponse(sesionJson()));

    await tester.pumpWidget(
      appConArgumentos(
        LoginService(api: mock.createService()),
        almacenamiento: AlmacenamientoFalso(),
        nombres: NombreUsuarioService(api: mock.createService()),
        alEntrarAInicio: (valor) => argumento = valor,
      ),
    );

    await entrar(tester, '1101812715', 'clave123');

    expect(argumento, isA<Sesion>());
    expect((argumento! as Sesion).token, 'jwt-sitram');
  });

  testWidgets('resuelve el nombre cuando el login no lo devuelve', (
    tester,
  ) async {
    Object? argumento;
    final almacenamiento = AlmacenamientoFalso();
    final mock = MockApi(
      (request) => request.url.path == '/api/auth/login'
          ? jsonResponse(loginSinNombre)
          : jsonResponse(asociadoConNombre),
    );
    final servicio = LoginService(api: mock.createService());

    await tester.pumpWidget(
      appConArgumentos(
        servicio,
        almacenamiento: almacenamiento,
        nombres: NombreUsuarioService(api: mock.createService()),
        alEntrarAInicio: (valor) => argumento = valor,
      ),
    );

    await entrar(tester, '1101812715', 'clave123');

    final sesion = argumento! as Sesion;
    expect(sesion.nombres, 'Ana Pérez');
    expect(sesion.empresa, 'TRANSPOMIX');
    expect(almacenamiento.sesionesGuardadas.last.nombres, 'Ana Pérez');
    expect(find.text('pantalla /home'), findsOneWidget);
  });

  testWidgets('un doble toque no envía dos logins', (tester) async {
    final completer = Completer<http.Response>();
    var pedidos = 0;
    final servicio = LoginService(
      api: ApiService(
        baseUrl: MockApi.baseUrl,
        timeout: const Duration(seconds: 5),
        client: MockClient((_) {
          pedidos++;
          return completer.future;
        }),
      ),
    );

    await tester.pumpWidget(appCon(servicio));
    await tester.enterText(
      find.byKey(const ValueKey('login-usuario')),
      '1101812715',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'clave123',
    );

    await tester.tap(find.byKey(const ValueKey('login-enviar')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('login-enviar')));
    await tester.pump();

    completer.complete(jsonResponse(sesionJson()));
    await tester.pumpAndSettle();

    expect(pedidos, 1);
    expect(find.text('pantalla /home'), findsOneWidget);
  });

  testWidgets('con requiereCambioPassword no entra y avisa', (tester) async {
    await tester.pumpWidget(
      appCon(servicioFalso(sesionJson(requiereCambioPassword: true))),
    );

    await entrar(tester, 'aperez', 'clave123');

    expect(
      find.text('Debes cambiar tu contraseña antes de continuar.'),
      findsOneWidget,
    );
    expect(find.text('pantalla /home'), findsNothing);
  });

  testWidgets('muestra el detail del backend cuando rechaza las credenciales', (
    tester,
  ) async {
    await tester.pumpWidget(
      appCon(
        servicioFalso({
          'title': 'Unauthorized',
          'detail': 'Credenciales inválidas.',
          'status': 401,
        }, status: 401),
      ),
    );

    await entrar(tester, 'aperez', 'mala');

    expect(
      find.text('No se pudo iniciar sesión. Credenciales inválidas.'),
      findsOneWidget,
    );
    expect(find.text('pantalla /home'), findsNothing);
  });

  testWidgets('sin red avisa que no se pudo conectar', (tester) async {
    final mock = MockApi((_) => throw Exception('sin red'));
    await tester.pumpWidget(appCon(LoginService(api: mock.createService())));

    await entrar(tester, 'aperez', 'clave123');

    expect(find.textContaining('al conectar la API'), findsOneWidget);
  });

  testWidgets('¿Olvidé mi contraseña? abre la recuperación', (tester) async {
    await tester.pumpWidget(appCon(servicioFalso(sesionJson())));

    await tester.tap(find.text('¿Olvidé mi contraseña?'));
    await tester.pumpAndSettle();

    expect(find.text('pantalla /reset-password'), findsOneWidget);
  });

  testWidgets('el ojo muestra y oculta la contraseña', (tester) async {
    await tester.pumpWidget(appCon(servicioFalso(sesionJson())));

    bool oculta() =>
        tester.widget<TextField>(find.byType(TextField).last).obscureText;

    expect(oculta(), isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(oculta(), isFalse);
    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pump();
    expect(oculta(), isTrue);
  });

  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('se adapta a $size sin desbordar', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appCon(servicioFalso(sesionJson())));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesión'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
}
