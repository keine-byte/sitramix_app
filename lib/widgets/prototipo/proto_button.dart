import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

enum ProtoBotonVariante { primario, secundario, peligro }

class ProtoButton extends StatelessWidget {
  const ProtoButton({
    required this.label,
    this.onPressed,
    this.variante = ProtoBotonVariante.primario,
    this.full = true,
    this.cargando = false,
    this.icono,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final ProtoBotonVariante variante;

  final bool full;

  final bool cargando;
  final IconData? icono;

  Color get _fondo => switch (variante) {
    ProtoBotonVariante.primario => AppTheme.amber,
    ProtoBotonVariante.secundario => AppTheme.gray,
    ProtoBotonVariante.peligro => AppTheme.red,
  };

  Color get _texto =>
      variante == ProtoBotonVariante.secundario ? AppTheme.dark : Colors.white;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    width: full ? double.infinity : null,
    child: FilledButton(
      onPressed: cargando ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _fondo,
        foregroundColor: _texto,
        disabledBackgroundColor: _fondo.withValues(alpha: 0.5),
        disabledForegroundColor: _texto,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: _contenido(),
    ),
  );

  Widget _contenido() {
    if (cargando) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        if (icono != null) ...[const SizedBox(width: 6), Icon(icono, size: 14)],
      ],
    );
  }
}
