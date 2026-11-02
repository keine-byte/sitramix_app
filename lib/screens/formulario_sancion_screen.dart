import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/sancion/sancion.dart';
import '../services/remote/api_service.dart';
import '../services/remote/sanciones_api.dart';
import '../utils/api_error_message.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/fields/custom_text_field.dart';
import '../widgets/forms/form_fields.dart';

class FormularioSancionScreen extends StatefulWidget {
  const FormularioSancionScreen({required this.api, super.key});

  final SancionesApi api;

  @override
  State<FormularioSancionScreen> createState() =>
      _FormularioSancionScreenState();
}

class _FormularioSancionScreenState extends State<FormularioSancionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _conductor = TextEditingController();
  final TextEditingController _motivo = TextEditingController();

  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  bool _guardando = false;
  String? _error;

  String? _errorFechas;

  @override
  void dispose() {
    _conductor.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _elegirInicio() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaInicio ?? DateUtils.dateOnly(DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: 'Inicio de la sanción',
    );
    if (elegida == null || !mounted) return;
    setState(() {
      _fechaInicio = elegida;
      _errorFechas = null;
    });
  }

  Future<void> _elegirFin() async {
    final base = _fechaInicio ?? DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaFin ?? base,
      firstDate: base,
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: 'Fin de la sanción',
    );
    if (elegida == null || !mounted) return;
    setState(() {
      _fechaFin = elegida;
      _errorFechas = null;
    });
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    final inicio = _fechaInicio;
    final fin = _fechaFin;
    if (inicio != null && fin != null && fin.isBefore(inicio)) {
      setState(
        () => _errorFechas =
            'La fecha de fin no puede ser anterior a la de inicio.',
      );
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
      _errorFechas = null;
    });
    try {
      final sancion = Sancion(
        identificacionConductor: _conductor.text.trim(),
        motivo: _motivo.text.trim(),
        fechaInicio: inicio,
        fechaFin: fin,
      );
      final guardada = await widget.api.crear(sancion);
      if (!mounted) return;
      Navigator.of(context).pop(guardada);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Nueva sanción'),
      titleTextStyle: const TextStyle(
        color: AppTheme.secondary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const Text(
                  'La sanción queda ACTIVA y bloquea la emisión de planillas '
                  'del conductor entre las dos fechas. Después solo se puede '
                  'marcar como cumplida o anular desde el detalle.',
                  style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _conductor,
                  label: 'Conductor',
                  hintText: 'Identificación, ej. 1099',
                  keyboardType: TextInputType.number,
                  enabled: !_guardando,
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Escribe la identificación del conductor.'
                      : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _motivo,
                  label: 'Motivo',
                  hintText: 'Ej. Reiteración de retrasos en la ruta',
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !_guardando,
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Escribe el motivo de la sanción.'
                      : null,
                ),
                const SizedBox(height: 12),
                CampoFecha(
                  etiqueta: 'Fecha de inicio',
                  valor: _fechaInicio,
                  habilitado: !_guardando,
                  onElegir: _elegirInicio,
                  onLimpiar: () => setState(() => _fechaInicio = null),
                ),
                CampoFecha(
                  etiqueta: 'Fecha de fin',
                  valor: _fechaFin,
                  habilitado: !_guardando,
                  onElegir: _elegirFin,
                  onLimpiar: () => setState(() => _fechaFin = null),
                ),
                const Text(
                  'El intervalo incluye los dos extremos. Sin fechas, la '
                  'sanción queda ACTIVA pero no bloquea un periodo concreto.',
                  style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_errorFechas != null) AvisoFormulario(_errorFechas!),
                if (_error != null) AvisoFormulario(_error!),
                PrimaryButton(
                  label: 'Registrar sanción',
                  isLoading: _guardando,
                  onPressed: _guardando ? null : _guardar,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
