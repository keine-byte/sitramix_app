import 'package:sitramix/models/sesion/sesion.dart';

abstract interface class SessionStorage {
  Future<void> saveToken(String token);
  Future<String?> readToken();

  Future<void> saveSesion(Sesion sesion);

  Future<Sesion?> readSesion();

  Future<void> clear();
}
