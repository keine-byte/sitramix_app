import 'package:sitramix/config/api_paths.dart';
import 'package:sitramix/config/app_config.dart';
import 'package:sitramix/models/login/login_request.dart';
import 'package:sitramix/models/sesion/sesion.dart';
import 'package:sitramix/services/remote/api_service.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

class LoginService {
  LoginService({ApiService? api})
    : _api = api ?? ApiService(baseUrl: AppConfig.apiBaseUrl);

  final ApiService _api;

  String get apiBaseUrl => _api.baseUrl;

  Future<Sesion> login(LoginRequest request) async {
    final json = await _api.post(ApiPaths.login, body: request.toJson());
    return parseJsonObject(json, Sesion.fromJson);
  }
}
