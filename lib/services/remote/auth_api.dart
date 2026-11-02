import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/models/sesion/sesion.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class AuthApi extends AuthenticatedApi {
  AuthApi({required super.api, super.token});

  Future<Sesion> login({
    required String username,
    required String password,
  }) async {
    final json = await api.post(
      ApiPaths.login,
      body: <String, dynamic>{'username': username, 'password': password},
    );
    return parseJsonObject(json, Sesion.fromJson);
  }

  Future<Sesion> cambiarPassword({
    required String nuevaPassword,
    required String confirmacionPassword,
    String? tokenCambio,
  }) async {
    final json = await api.post(
      ApiPaths.cambiarPassword,
      body: <String, dynamic>{
        'nuevaPassword': nuevaPassword,
        'confirmacionPassword': confirmacionPassword,
      },
      headers: _bearerHeader(tokenCambio ?? token),
    );
    return parseJsonObject(json, Sesion.fromJson);
  }

  Future<Sesion> registrarUsuario({
    required String identificacion,
    required String nombres,
    required String username,
    required String password,
    required Rol rol,
    bool activo = true,
  }) async {
    final json = await api.post(
      ApiPaths.registrarUsuario,
      body: <String, dynamic>{
        'identificacion': identificacion,
        'nombres': nombres,
        'username': username,
        'password': password,
        'rol': rol.apiValue,
        'activo': activo,
      },
      headers: authHeaders,
    );
    return parseJsonObject(json, Sesion.fromJson);
  }

  Map<String, String> _bearerHeader(String? value) {
    final tokenValue = value?.trim();
    if (tokenValue == null || tokenValue.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $tokenValue'};
  }
}
