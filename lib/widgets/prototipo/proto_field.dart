import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';

class ProtoField extends StatefulWidget {
  const ProtoField({
    required this.label,
    this.controller,
    this.hintText,
    this.esPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autocorrect = true,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;

  final bool esPassword;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  final bool enabled;

  final int maxLines;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool autocorrect;

  @override
  State<ProtoField> createState() => _ProtoFieldState();
}

class _ProtoFieldState extends State<ProtoField> {
  bool _oculto = true;

  @override
  void initState() {
    super.initState();
    _oculto = widget.esPassword;
  }

  OutlineInputBorder _borde(Color color, double ancho) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: color, width: ancho),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label.toUpperCase(),
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: AppTheme.dark,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 4),
      TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: _oculto,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        autocorrect: widget.autocorrect,
        enableSuggestions: !widget.esPassword,
        maxLines: widget.esPassword ? 1 : widget.maxLines,
        textCapitalization: widget.textCapitalization,
        inputFormatters: widget.inputFormatters,
        onFieldSubmitted: widget.onFieldSubmitted,
        validator: widget.validator,
        style: const TextStyle(fontSize: 11, color: AppTheme.dark),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          hintText: widget.hintText,
          hintStyle: const TextStyle(fontSize: 11, color: AppTheme.muted),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 9,
            vertical: widget.maxLines > 1 ? 8 : 9,
          ),
          border: _borde(AppTheme.border, 0.9),
          enabledBorder: _borde(AppTheme.border, 0.9),
          disabledBorder: _borde(AppTheme.border, 0.9),
          focusedBorder: _borde(AppTheme.amber, 1),
          errorBorder: _borde(AppTheme.red, 0.9),
          focusedErrorBorder: _borde(AppTheme.red, 1),
          errorStyle: const TextStyle(fontSize: 9, color: AppTheme.red),
          suffixIcon: widget.esPassword ? _ojo() : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 30,
            minHeight: 30,
          ),
        ),
      ),
    ],
  );

  Widget _ojo() => IconButton(
    tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
    onPressed: () => setState(() => _oculto = !_oculto),
    padding: EdgeInsets.zero,
    iconSize: 16,
    color: AppTheme.muted,
    style: IconButton.styleFrom(
      minimumSize: const Size(30, 30),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    icon: Icon(
      _oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined,
    ),
  );
}
