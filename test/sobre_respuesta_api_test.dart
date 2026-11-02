import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/services/remote/api_service.dart';
import 'package:sitramix/services/remote/authenticated_api.dart';

Map<String, Object?> sobrePaginado(List<Map<String, Object?>> items) =>
    <String, Object?>{
      'message': 'Recursos consultados correctamente.',
      'data': <String, Object?>{
        'items': items,
        'pagination': <String, Object?>{
          'page': 1,
          'pageSize': 20,
          'totalItems': items.length,
          'totalPages': 1,
        },
      },
      'success': true,
    };

void main() {
  test('desenvuelve el sobre {message, data, success} de los módulos', () {
    expect(
      desenvuelveRespuestaApi(<String, dynamic>{
        'message': 'ok',
        'data': <String, dynamic>{'identificacion': '1'},
        'success': true,
      }),
      <String, dynamic>{'identificacion': '1'},
    );
  });

  test('deja intactas las respuestas planas (login, cambiar-password)', () {
    final plano = <String, dynamic>{'token': 'jwt', 'rol': 'GERENTE'};
    expect(desenvuelveRespuestaApi(plano), same(plano));
    expect(desenvuelveRespuestaApi(<dynamic>[1, 2]), <dynamic>[1, 2]);
    expect(desenvuelveRespuestaApi(null), isNull);
  });

  test('parseJsonList lee data.items del listado paginado', () {
    final json = sobrePaginado(<Map<String, Object?>>[
      <String, Object?>{'identificacion': '1'},
      <String, Object?>{'identificacion': '2'},
    ]);

    final lista = parseJsonList<String>(
      json,
      (fila) => fila['identificacion']! as String,
    );

    expect(lista, <String>['1', '2']);
  });

  test('parseJsonList sigue aceptando una lista suelta', () {
    final lista = parseJsonList<String>(<dynamic>[
      <String, dynamic>{'identificacion': '1'},
    ], (fila) => fila['identificacion']! as String);

    expect(lista, <String>['1']);
  });

  test('parseJsonObject lee data del sobre', () {
    final json = <String, Object?>{
      'message': 'Recurso consultado correctamente.',
      'data': <String, Object?>{'identificacion': '1', 'nombres': 'Ana'},
      'success': true,
    };

    final fila = parseJsonObject<Map<String, dynamic>>(json, (valor) => valor);

    expect(fila['nombres'], 'Ana');
  });

  test('un cuerpo sin lista sigue siendo un error de API', () {
    expect(
      () => parseJsonList<Object?>(<String, Object?>{
        'message': 'sin datos',
      }, (fila) => fila),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => parseJsonObject<Object?>('<html>', (valor) => valor),
      throwsA(isA<ApiException>()),
    );
  });
}
