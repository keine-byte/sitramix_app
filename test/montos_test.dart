import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/utils/montos.dart';

void main() {
  test('formatea enteros con separador de miles', () {
    expect(formatearMonto(4000), '\$ 4.000');
    expect(formatearMonto(0), '\$ 0');
    expect(formatearMonto(1234567), '\$ 1.234.567');
  });

  test('agrega los centavos con coma solo cuando existen', () {
    expect(formatearMonto(12500.5), '\$ 12.500,50');
    expect(formatearMonto(99.99), '\$ 99,99');
  });

  test('un valor nulo o negativo se distingue', () {
    expect(formatearMonto(null), '—');
    expect(formatearMonto(null, vacio: 'sin asignar'), 'sin asignar');
    expect(formatearMonto(-2500), '\$ -2.500');
  });
}
