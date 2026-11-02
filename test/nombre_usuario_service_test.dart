import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/models/sesion/sesion.dart';
import 'package:sitramix/services/remote/nombre_usuario_service.dart';

import 'helpers/mock_api.dart';

const sesionGerente = Sesion(
  token: 'jwt',
  rol: Rol.gerente,
  identificacion: '1101812715',
  username: '1101812715',
);

Map<String, Object?> asociadoJson(String nombres) => <String, Object?>{
  'message': 'Recurso consultado correctamente.',
  'data': <String, Object?>{
    'identificacion': '1101812715',
    'nombres': nombres,
    'username': '1101812715',
    'activo': true,
  },
  'success': true,
};

void main() {
  test('trae el nombre del asociado con la misma identificación', () async {
    final mock = MockApi((_) => jsonResponse(asociadoJson('Ana Pérez')));
    final servicio = NombreUsuarioService(api: mock.createService());

    final resultado = await servicio.completar(sesionGerente);

    expect(resultado.nombres, 'Ana Pérez');
    expect(resultado.token, sesionGerente.token);
    expect(mock.lastRequest.url.path, '/api/asociados/1101812715');
    expect(mock.lastRequest.headers['Authorization'], 'Bearer jwt');
  });

  test('sin asociado con esa identificación la sesión no cambia', () async {
    final mock = MockApi(
      (_) => jsonResponse(<String, Object?>{
        'code': 'RESOURCE_NOT_FOUND',
        'message': 'El recurso no fue encontrado.',
      }, status: 404),
    );
    final servicio = NombreUsuarioService(api: mock.createService());

    final resultado = await servicio.completar(sesionGerente);

    expect(resultado.nombres, isNull);
    expect(resultado, same(sesionGerente));
  });

  test('no consulta nada si el login ya trajo el nombre', () async {
    final mock = MockApi((_) => throw Exception('no debe consultarse'));
    final servicio = NombreUsuarioService(api: mock.createService());

    const sesion = Sesion(token: 'jwt', rol: Rol.gerente, nombres: 'Ana');
    final resultado = await servicio.completar(sesion);

    expect(resultado, same(sesion));
    expect(mock.requests, isEmpty);
  });

  test(
    'no consulta Asociados con el token de un ASOCIADO (sería 403)',
    () async {
      final mock = MockApi((_) => throw Exception('no debe consultarse'));
      final servicio = NombreUsuarioService(api: mock.createService());

      const sesion = Sesion(
        token: 'jwt-asociado',
        rol: Rol.asociado,
        identificacion: '12457899',
        username: '12457899',
      );
      final resultado = await servicio.completar(sesion);

      expect(resultado, same(sesion));
      expect(mock.requests, isEmpty);
    },
  );

  test('si la red falla la sesión se conserva', () async {
    final mock = MockApi((_) => throw Exception('sin red'));
    final servicio = NombreUsuarioService(api: mock.createService());

    final resultado = await servicio.completar(sesionGerente);

    expect(resultado.nombres, isNull);
  });

  test('un nombre igual a la identificación no se usa', () async {
    final mock = MockApi((_) => jsonResponse(asociadoJson('1101812715')));
    final servicio = NombreUsuarioService(api: mock.createService());

    final resultado = await servicio.completar(sesionGerente);

    expect(resultado.nombres, isNull);
  });
}
