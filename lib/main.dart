import 'package:flutter/material.dart';

import 'config/app_theme.dart';
import 'models/sesion/sesion.dart';
import 'routes/app_routes.dart';
import 'screens/inicio_screen.dart';
import 'screens/login_screen.dart';
import 'screens/restablecer_contrasena_screen.dart';
import 'screens/splash_screen.dart';
import 'services/local/secure_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sesion = await const SecureStorageService().readSesion();
  runApp(SitramixApp(sesionInicial: sesion, mostrarSplash: true));
}

class SitramixApp extends StatelessWidget {
  const SitramixApp({
    super.key,
    this.sesionInicial,
    this.mostrarSplash = false,
  });

  final Sesion? sesionInicial;

  final bool mostrarSplash;

  String get _rutaConSesion =>
      sesionInicial == null ? AppRoutes.login : AppRoutes.home;

  Sesion? _sesionDeRuta(Object? argumento) =>
      argumento is Sesion ? argumento : sesionInicial;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SITRAMIX',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.tema,
    initialRoute: mostrarSplash ? AppRoutes.splash : _rutaConSesion,
    onGenerateRoute: (settings) {
      switch (settings.name) {
        case AppRoutes.splash:
          return MaterialPageRoute(
            builder: (context) => SplashScreen(rutaSiguiente: _rutaConSesion),
          );
        case AppRoutes.login:
          return MaterialPageRoute(builder: (context) => const LoginScreen());
        case AppRoutes.home:
          return MaterialPageRoute(
            builder: (context) =>
                InicioScreen(sesionInicial: _sesionDeRuta(settings.arguments)),
          );
        case AppRoutes.resetPassword:
          return MaterialPageRoute(
            builder: (context) => const ResetPasswordScreen(),
          );
        default:
          return MaterialPageRoute(builder: (context) => const LoginScreen());
      }
    },
  );
}
