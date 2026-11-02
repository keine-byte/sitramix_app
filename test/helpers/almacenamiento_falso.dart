import 'package:sitramix/models/sesion/sesion.dart';
import 'package:sitramix/services/local/session_storage.dart';

class AlmacenamientoFalso implements SessionStorage {
  AlmacenamientoFalso({this.sesion, this.token = 'jwt'});

  Sesion? sesion;
  String? token;

  int limpiezas = 0;

  final List<Sesion> sesionesGuardadas = <Sesion>[];

  @override
  Future<void> clear() async {
    limpiezas++;
    token = null;
    sesion = null;
  }

  @override
  Future<Sesion?> readSesion() async => sesion;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> saveSesion(Sesion sesion) async {
    this.sesion = sesion;
    sesionesGuardadas.add(sesion);
  }

  @override
  Future<void> saveToken(String token) async => this.token = token;
}
