library;

String formatearFecha(DateTime? fecha, {String vacio = '—'}) {
  if (fecha == null) return vacio;
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}
