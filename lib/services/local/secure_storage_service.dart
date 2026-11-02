import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sitramix/models/sesion/sesion.dart';

import 'session_storage.dart';

class SecureStorageService implements SessionStorage {
  const SecureStorageService({this.storage = const FlutterSecureStorage()});

  static const String tokenKey = 'token';
  static const String sesionKey = 'sesion';

  final FlutterSecureStorage storage;

  @override
  Future<void> saveToken(String token) async {
    try {
      await storage.write(key: tokenKey, value: token);
    } on Exception catch (error) {
      debugPrint('No se pudo guardar el token: $error');
    }
  }

  @override
  Future<String?> readToken() async {
    try {
      return await storage.read(key: tokenKey);
    } on Exception catch (error) {
      debugPrint('No se pudo leer el token: $error');
      return null;
    }
  }

  @override
  Future<void> saveSesion(Sesion sesion) async {
    if (!sesion.tieneAcceso) {
      await clear();
      return;
    }
    try {
      await storage.write(key: sesionKey, value: sesion.encode());
      await storage.write(key: tokenKey, value: sesion.token);
    } on Exception catch (error) {
      debugPrint('No se pudo guardar la sesión: $error');
    }
  }

  @override
  Future<Sesion?> readSesion() async {
    try {
      final sesion = Sesion.tryDecode(await storage.read(key: sesionKey));
      return sesion != null && sesion.tieneAcceso ? sesion : null;
    } on Exception catch (error) {
      debugPrint('No se pudo leer la sesión: $error');
      return null;
    }
  }

  @override
  Future<void> clear() async {
    try {
      await storage.delete(key: tokenKey);
      await storage.delete(key: sesionKey);
    } on Exception catch (error) {
      debugPrint('No se pudo limpiar la sesión: $error');
    }
  }
}
