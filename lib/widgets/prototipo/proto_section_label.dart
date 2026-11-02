import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

class ProtoSectionLabel extends StatelessWidget {
  const ProtoSectionLabel({
    required this.texto,
    this.cargando = false,
    super.key,
  });

  final String texto;

  final bool cargando;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(height: 1, width: 12, color: AppTheme.amber),
      const SizedBox(width: 8),
      Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppTheme.amber,
          letterSpacing: 1.3,
        ),
      ),
      if (cargando) ...[
        const SizedBox(width: 8),
        const SizedBox(
          width: 9,
          height: 9,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppTheme.amber,
          ),
        ),
      ],
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: AppTheme.rule)),
    ],
  );
}
