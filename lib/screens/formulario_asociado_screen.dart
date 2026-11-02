import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/asociado/asociado.dart';
import '../services/remote/api_service.dart';
import '../services/remote/asociados_api.dart';
import '../utils/api_error_message.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/fields/custom_text_field.dart';
import '../widgets/forms/form_fields.dart';

class FormularioAsociadoScreen extends StatefulWidget {
  const FormularioAsociadoScreen({required this.api, this.asociado, super.key});

  final AsociadosApi api;

  final Asociado? asociado;

  bool get esEdicion => asociado != null;

  @override
  State<FormularioAsociadoScreen> createState() =>
      _FormularioAsociadoScreenState();
}

class _FormularioAsociadoScreenState extends State<FormularioAsociadoScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _identificacion = TextEditingController(
    text: widget.asociado?.identificacion ?? '',
  );
  late final TextEditingController _nombres = TextEditingController(
    text: widget.asociado?.nombres ?? '',
  );
  late final TextEditingController _celular = TextEditingController(
    text: widget.asociado?.celular ?? '',
  );
  late final TextEditingController _correo = TextEditingController(
    text: widget.asociado?.correo ?? '',
  );

  late DateTime? _fechaNacimiento = widget.asociado?.fechaNacimiento;
  late DateTime? _fechaIngreso = widget.asociado?.fechaIngreso;
  late bool _activo = widget.asociado?.activo ?? true;

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _identificacion.dispose();
    _nombres.dispose();
    _celular.dispose();
    _correo.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha({
    required DateTime? actual,
    required String ayuda,
    required DateTime inicial,
    required ValueChanged<DateTime?> asignar,
  }) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual ?? inicial,
      firstDate: DateTime(1900),
      lastDate: hoy,
      helpText: ayuda,
    );
    if (elegida == null || !mounted) return;
    setState(() => asignar(elegida));
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final asociado = Asociado(
        identificacion: _identificacion.text.trim(),
        nombres: _nombres.text.trim(),
        activo: _activo,
        celular: textoONull(_celular.text),
        correo: textoONull(_correo.text),
        fechaNacimiento: _fechaNacimiento,
        fechaIngreso: _fechaIngreso,
      );
      final guardado = widget.esEdicion
          ? await widget.api.actualizar(asociado)
          : await widget.api.crear(asociado);
      if (!mounted) return;
      Navigator.of(context).pop(guardado);
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
      title: Text(widget.esEdicion ? 'Editar asociado' : 'Nuevo asociado'),
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
                  'La identificación no se puede cambiar después de crear el '
                  'asociado.',
                  style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _identificacion,
                  label: 'Identificación',
                  hintText: 'Ej. 1098765432',
                  enabled: !widget.esEdicion && !_guardando,
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Escribe la identificación.'
                      : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _nombres,
                  label: 'Nombres',
                  hintText: 'Ej. Ana Pérez',
                  enabled: !_guardando,
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Escribe los nombres.'
                      : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _celular,
                  label: 'Celular',
                  hintText: 'Ej. 3001234567',
                  keyboardType: TextInputType.phone,
                  enabled: !_guardando,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _correo,
                  label: 'Correo',
                  hintText: 'Ej. ana@correo.com',
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enabled: !_guardando,
                ),
                const SizedBox(height: 4),
                CampoFecha(
                  etiqueta: 'Fecha de nacimiento',
                  valor: _fechaNacimiento,
                  habilitado: !_guardando,
                  onElegir: () => _elegirFecha(
                    actual: _fechaNacimiento,
                    ayuda: 'Fecha de nacimiento',
                    inicial: DateTime(1990),
                    asignar: (valor) => _fechaNacimiento = valor,
                  ),
                  onLimpiar: () => setState(() => _fechaNacimiento = null),
                ),
                if (widget.esEdicion)
                  CampoFecha(
                    etiqueta: 'Fecha de ingreso',
                    valor: _fechaIngreso,
                    habilitado: !_guardando,
                    onElegir: () => _elegirFecha(
                      actual: _fechaIngreso,
                      ayuda: 'Fecha de ingreso',
                      inicial: DateTime.now(),
                      asignar: (valor) => _fechaIngreso = valor,
                    ),
                    onLimpiar: () => setState(() => _fechaIngreso = null),
                  ),
                CampoActivo(
                  etiqueta: 'Asociado activo',
                  valor: _activo,
                  habilitado: !_guardando,
                  onChanged: (valor) => setState(() => _activo = valor),
                ),
                const SizedBox(height: 8),
                if (_error != null) AvisoFormulario(_error!),
                PrimaryButton(
                  label: widget.esEdicion
                      ? 'Guardar cambios'
                      : 'Registrar asociado',
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
