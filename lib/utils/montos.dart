library;

String formatearMonto(double? valor, {String vacio = '—'}) {
  if (valor == null) return vacio;
  final partes = valor.abs().toStringAsFixed(2).split('.');
  final entero = _agruparMiles(partes.first);
  final decimales = partes.last == '00' ? '' : ',${partes.last}';
  return '\$ ${valor < 0 ? '-' : ''}$entero$decimales';
}

String _agruparMiles(String digitos) {
  final buffer = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digitos[i]);
  }
  return buffer.toString();
}
