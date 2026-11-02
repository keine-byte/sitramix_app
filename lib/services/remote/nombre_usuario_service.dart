import 'dart:async';

import 'package:sitramix/config/app_config.dart';
import 'package:sitramix/models/sesion/sesion.dart';
import 'package:sitramix/services/remote/api_service.dart';
import 'package:sitramix/services/remote/asociados_api.dart';

class NombreUsuarioService {
  NombreUsuarioService({ApiService? api})
    : _api = api ?? ApiService(baseUrl: AppConfig.apiBaseUrl);

  static const Duration _limite = Duration(seconds: 5);

  final ApiService _api;

  Future<Sesion> completar(Sesion sesion) async {
    if (sesion.nombres != null) return sesion;

    final identificacion = sesion.identificacion;
    if (identificacion == null || sesion.esAsociado) return sesion;

    try {
      final asociado = await AsociadosApi(
        api: _api,
        token: sesion.token,
      ).consultar(identificacion).timeout(_limite);
      final nombres = asociado.nombres.trim();
      if (nombres.isEmpty || nombres == identificacion) return sesion;
      return sesion.conNombres(nombres);
    } catch (_) {
      return sesion;
    }
  }
}
