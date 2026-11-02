import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/local/secure_storage_service.dart';
import '../services/local/session_storage.dart';
import '../services/remote/api_service.dart';

const String mensajeSesionExpirada =
    'Tu sesión expiró. Vuelve a iniciar sesión.';

const Duration _limiteLimpieza = Duration(seconds: 1);

Future<bool> cerrarSesionSiExpirada(
  BuildContext context,
  ApiException error, {
  SessionStorage storage = const SecureStorageService(),
  void Function(BuildContext context)? irAlLogin,
}) async {
  if (error.statusCode != 401) return false;

  await storage.clear().timeout(
    _limiteLimpieza,
    onTimeout: () => debugPrint('La sesión no se borró del almacenamiento.'),
  );
  if (!context.mounted) return true;

  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(const SnackBar(content: Text(mensajeSesionExpirada)));

  (irAlLogin ?? _irAlLogin)(context);
  return true;
}

void _irAlLogin(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
}
