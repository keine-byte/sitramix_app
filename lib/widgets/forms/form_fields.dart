import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../utils/fechas.dart';

class CampoFecha extends StatelessWidget {
  const CampoFecha({
    required this.etiqueta,
    required this.valor,
    required this.onElegir,
    this.onLimpiar,
    this.habilitado = true,
    super.key,
  });

  final String etiqueta;
  final DateTime? valor;
  final VoidCallback onElegir;
  final VoidCallback? onLimpiar;
  final bool habilitado;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: habilitado ? onElegir : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          filled: true,
          fillColor: const Color(0xFFF7F8FC),
          contentPadding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
          border: _borde(const Color(0xFFE5E7EF)),
          enabledBorder: _borde(const Color(0xFFE5E7EF)),
          focusedBorder: _borde(AppTheme.primary, ancho: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valor == null ? 'Sin fecha' : formatearFecha(valor),
                style: TextStyle(
                  color: valor == null
                      ? const Color(0xFF77798B)
                      : const Color(0xFF3C3E4F),
                ),
              ),
            ),
            if (valor != null && onLimpiar != null)
              IconButton(
                tooltip: 'Quitar fecha',
                visualDensity: VisualDensity.compact,
                onPressed: habilitado ? onLimpiar : null,
                icon: const Icon(Icons.close_rounded, size: 18),
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.event_rounded,
                  size: 20,
                  color: Color(0xFF77798B),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class CampoHora extends StatelessWidget {
  const CampoHora({
    required this.etiqueta,
    required this.valor,
    required this.onElegir,
    this.onLimpiar,
    this.habilitado = true,
    super.key,
  });

  final String etiqueta;
  final TimeOfDay? valor;
  final VoidCallback onElegir;
  final VoidCallback? onLimpiar;
  final bool habilitado;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: habilitado ? onElegir : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          filled: true,
          fillColor: const Color(0xFFF7F8FC),
          contentPadding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
          border: _borde(const Color(0xFFE5E7EF)),
          enabledBorder: _borde(const Color(0xFFE5E7EF)),
          focusedBorder: _borde(AppTheme.primary, ancho: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valor == null ? 'Sin hora' : horaCorta(valor!),
                style: TextStyle(
                  color: valor == null
                      ? const Color(0xFF77798B)
                      : const Color(0xFF3C3E4F),
                ),
              ),
            ),
            if (valor != null && onLimpiar != null)
              IconButton(
                tooltip: 'Quitar hora',
                visualDensity: VisualDensity.compact,
                onPressed: habilitado ? onLimpiar : null,
                icon: const Icon(Icons.close_rounded, size: 18),
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: Color(0xFF77798B),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

String horaCorta(TimeOfDay hora) =>
    '${hora.hour.toString().padLeft(2, '0')}:'
    '${hora.minute.toString().padLeft(2, '0')}';

String horaApi(TimeOfDay hora) => '${horaCorta(hora)}:00';

class CampoActivo extends StatelessWidget {
  const CampoActivo({
    required this.etiqueta,
    required this.valor,
    required this.onChanged,
    this.habilitado = true,
    super.key,
  });

  final String etiqueta;
  final bool valor;
  final ValueChanged<bool> onChanged;
  final bool habilitado;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(etiqueta, style: const TextStyle(fontSize: 14)),
    value: valor,
    onChanged: habilitado ? onChanged : null,
  );
}

class AvisoFormulario extends StatelessWidget {
  const AvisoFormulario(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: AppTheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A1C1C)),
          ),
        ),
      ],
    ),
  );
}

OutlineInputBorder _borde(Color color, {double ancho = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: ancho),
    );

String? textoONull(String texto) {
  final limpio = texto.trim();
  return limpio.isEmpty ? null : limpio;
}
