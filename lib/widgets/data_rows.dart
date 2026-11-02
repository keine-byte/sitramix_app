import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {required this.color, super.key});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      texto,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
  );
}

class DatoFila extends StatelessWidget {
  const DatoFila(this.icon, this.texto, {super.key});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: const Color(0xFF77798B)),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          texto,
          style: const TextStyle(color: Color(0xFF55576B), fontSize: 13),
        ),
      ),
    ],
  );
}

class CampoDetalle extends StatelessWidget {
  const CampoDetalle(this.icon, this.etiqueta, this.valor, {super.key});

  final IconData icon;
  final String etiqueta;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    final texto = valor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF77798B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: const TextStyle(
                    color: Color(0xFF77798B),
                    fontSize: 12,
                  ),
                ),
                Text(
                  texto == null || texto.isEmpty ? '—' : texto,
                  style: const TextStyle(
                    color: Color(0xFF55576B),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AvisoAccion extends StatelessWidget {
  const AvisoAccion(
    this.texto, {
    required this.onAccion,
    this.etiquetaAccion = 'Reintentar',
    this.habilitado = true,
    super.key,
  });

  final String texto;
  final VoidCallback onAccion;
  final String etiquetaAccion;
  final bool habilitado;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
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
        TextButton(
          onPressed: habilitado ? onAccion : null,
          child: Text(etiquetaAccion),
        ),
      ],
    ),
  );
}
