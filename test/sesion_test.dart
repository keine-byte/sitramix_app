import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/models/sesion/sesion.dart';

void main() {
  group('Sesion.encode / Sesion.tryDecode', () {
    test('la ida y vuelta conserva token, rol y datos del usuario', () {
      const original = Sesion(
        token: 'jwt-123',
        rol: Rol.asistente,
        identificacion: '1099',
        nombres: 'Ana Pérez',
        username: 'aperez',
      );

      final copia = Sesion.tryDecode(original.encode());

      expect(copia, isNotNull);
      expect(copia!.token, 'jwt-123');
      expect(copia.rol, Rol.asistente);
      expect(copia.identificacion, '1099');
      expect(copia.nombres, 'Ana Pérez');
      expect(copia.username, 'aperez');
      expect(copia.requiereCambioPassword, isFalse);
      expect(copia.tieneAcceso, isTrue);
    });

    test('un rol que la app no conoce se rehidrata como desconocido', () {
      final sesion = Sesion.tryDecode('{"token":"jwt","rol":"CONTADOR"}');

      expect(sesion?.rol, Rol.desconocido);
    });

    test('texto vacío, JSON corrupto o lista devuelven null', () {
      expect(Sesion.tryDecode(null), isNull);
      expect(Sesion.tryDecode('   '), isNull);
      expect(Sesion.tryDecode('{no-es-json'), isNull);
      expect(Sesion.tryDecode('[1, 2, 3]'), isNull);
    });

    test('una sesión guardada sin token no se rehidrata', () {
      expect(Sesion.tryDecode('{"token":"","rol":"GERENTE"}'), isNull);
    });

    test('requiereCambioPassword deja la sesión sin acceso', () {
      final sesion = Sesion.tryDecode(
        '{"token":"jwt","rol":"ASOCIADO","requiereCambioPassword":true}',
      );

      expect(sesion, isNotNull);
      expect(sesion!.requiereCambioPassword, isTrue);
      expect(sesion.tieneAcceso, isFalse);
    });
  });

  group('Sesion.fromJson (auth/login real)', () {
    const respuesta = <String, dynamic>{
      'token': 'jwt-123',
      'tipo': 'Bearer',
      'expiraEn': 3600000,
      'identificacion': '1101812715',
      'username': '1101812715',
      'rol': 'GERENTE',
      'requiereCambioPassword': false,
      'empresa': <String, dynamic>{'id': 8, 'razonSocial': 'TRANSPOMIX'},
    };

    test('lee identificacion, username y la razón social de la empresa', () {
      final sesion = Sesion.fromJson(respuesta);

      expect(sesion.token, 'jwt-123');
      expect(sesion.rol, Rol.gerente);
      expect(sesion.identificacion, '1101812715');
      expect(sesion.username, '1101812715');
      expect(sesion.empresa, 'TRANSPOMIX');
      expect(sesion.nombres, isNull);
    });

    test('la empresa sobrevive la ida y vuelta al almacenamiento', () {
      final copia = Sesion.tryDecode(Sesion.fromJson(respuesta).encode());

      expect(copia?.empresa, 'TRANSPOMIX');
      expect(copia?.identificacion, '1101812715');
    });

    test('conNombres conserva el resto de la sesión', () {
      final sesion = Sesion.fromJson(respuesta).conNombres('Ana Pérez');

      expect(sesion.nombres, 'Ana Pérez');
      expect(sesion.token, 'jwt-123');
      expect(sesion.rol, Rol.gerente);
      expect(sesion.empresa, 'TRANSPOMIX');
      expect(sesion.identificacion, '1101812715');
    });
  });
}
