import 'package:shared_preferences/shared_preferences.dart';

class UsuarioPreferencesService {
  Future<void> guardarUsuario({
    required int id,
    required String nombre,
    required String correo,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('usuario_identificacion', id);
    await prefs.setString('usuario_nombre', nombre);
    await prefs.setString('usuario_correo', correo);
  }

  Future<int?> obtenerId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt('usuario_identificacion');
  }

  Future<String?> obtenerNombre() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('usuario_nombre');
  }

  Future<String?> obtenerCorreo() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('usuario_correo');
  }

  Future<void> eliminarUsuario() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('usuario_identificacion');
    await prefs.remove('usuario_nombre');
    await prefs.remove('usuario_correo');
  }
}
