import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/conductor/conductor.dart';
import '../services/remote/api_service.dart';
import '../services/remote/conductores_api.dart';
import '../utils/api_error_message.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/fields/custom_text_field.dart';
import '../widgets/forms/form_fields.dart';

class FormularioConductorScreen extends StatefulWidget {
  const FormularioConductorScreen({
    required this.api,
    this.conductor,
    super.key,
  });

  final ConductoresApi api;

  final Conductor? conductor;

  bool get esEdicion => conductor != null;

  @override
  State<FormularioConductorScreen> createState() =>
      _FormularioConductorScreenState();
}

class _FormularioConductorScreenState extends State<FormularioConductorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _identificacion = TextEditingController(
    text: widget.conductor?.identificacion ?? '',
  );
  late final TextEditingController _nombres = TextEditingController(
    text: widget.conductor?.nombres ?? '',
  );
  late final TextEditingController _numeroLicencia = TextEditingController(
    text: widget.conductor?.numeroLicencia ?? '',
  );
  late final TextEditingController _categoriaLicencia = TextEditingController(
    text: widget.conductor?.categoriaLicencia ?? '',
  );
  late final TextEditingController _celular = TextEditingController(
    text: widget.conductor?.celular ?? '',
  );
  late final TextEditingController _correo = TextEditingController(
    text: widget.conductor?.correo ?? '',
  );

  late DateTime? _fechaNacimiento = widget.conductor?.fechaNacimiento;
  late DateTime? _vigenciaLicencia = widget.conductor?.vigenciaLicencia;
  late bool _activo = widget.conductor?.activo ?? true;

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _identificacion.dispose();
    _nombres.dispose();
    _numeroLicencia.dispose();
    _categoriaLicencia.dispose();
    _celular.dispose();
    _correo.dispose();
    super.dispose();
  }

  Future<DateTime?> _pedirFecha({
    required DateTime? actual,
    required String ayuda,
    required DateTime inicial,
    DateTime? ultima,
  }) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual ?? inicial,
      firstDate: DateTime(1900),
      lastDate: ultima ?? hoy,
      helpText: ayuda,
    );
    return elegida;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final conductor = Conductor(
        identificacion: _identificacion.text.trim(),
        nombres: _nombres.text.trim(),
        activo: _activo,
        fechaNacimiento: _fechaNacimiento,
        numeroLicencia: textoONull(_numeroLicencia.text),
        categoriaLicencia: textoONull(_categoriaLicencia.text),
        vigenciaLicencia: _vigenciaLicencia,
        celular: textoONull(_celular.text),
        correo: textoONull(_correo.text),
      );
      final guardado = widget.esEdicion
          ? await widget.api.actualizar(conductor)
          : await widget.api.crear(conductor);
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
      title: Text(widget.esEdicion ? 'Editar conductor' : 'Nuevo conductor'),
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
                  'conductor.',
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
                  hintText: 'Ej. Carlos Ruiz',
                  enabled: !_guardando,
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Escribe los nombres.'
                      : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _numeroLicencia,
                  label: 'Número de licencia',
                  hintText: 'Ej. LC-123456',
                  enabled: !_guardando,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _categoriaLicencia,
                  label: 'Categoría de la licencia',
                  hintText: 'Ej. C2',
                  enabled: !_guardando,
                ),
                const SizedBox(height: 4),
                CampoFecha(
                  etiqueta: 'Vigencia de la licencia',
                  valor: _vigenciaLicencia,
                  habilitado: !_guardando,
                  onElegir: () async {
                    final elegida = await _pedirFecha(
                      actual: _vigenciaLicencia,
                      ayuda: 'Vigencia de la licencia',
                      inicial: DateTime.now(),
                      ultima: DateTime(DateTime.now().year + 20),
                    );
                    if (elegida == null || !mounted) return;
                    setState(() => _vigenciaLicencia = elegida);
                  },
                  onLimpiar: () => setState(() => _vigenciaLicencia = null),
                ),
                CampoFecha(
                  etiqueta: 'Fecha de nacimiento',
                  valor: _fechaNacimiento,
                  habilitado: !_guardando,
                  onElegir: () async {
                    final elegida = await _pedirFecha(
                      actual: _fechaNacimiento,
                      ayuda: 'Fecha de nacimiento',
                      inicial: DateTime(1990),
                    );
                    if (elegida == null || !mounted) return;
                    setState(() => _fechaNacimiento = elegida);
                  },
                  onLimpiar: () => setState(() => _fechaNacimiento = null),
                ),
                const SizedBox(height: 8),
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
                  hintText: 'Ej. carlos@correo.com',
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enabled: !_guardando,
                ),
                const SizedBox(height: 4),
                CampoActivo(
                  etiqueta: 'Conductor activo',
                  valor: _activo,
                  habilitado: !_guardando,
                  onChanged: (valor) => setState(() => _activo = valor),
                ),
                const SizedBox(height: 8),
                if (_error != null) AvisoFormulario(_error!),
                PrimaryButton(
                  label: widget.esEdicion
                      ? 'Guardar cambios'
                      : 'Registrar conductor',
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
