import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/planilla/planilla.dart';
import '../services/remote/api_service.dart';
import '../services/remote/planillas_api.dart';
import '../utils/api_error_message.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/fields/custom_text_field.dart';
import '../widgets/forms/form_fields.dart';

class FormularioPlanillaScreen extends StatefulWidget {
  const FormularioPlanillaScreen({required this.api, super.key});

  final PlanillasApi api;

  @override
  State<FormularioPlanillaScreen> createState() =>
      _FormularioPlanillaScreenState();
}

class _FormularioPlanillaScreenState extends State<FormularioPlanillaScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _placa = TextEditingController();
  final TextEditingController _tipo = TextEditingController(text: 'VIAJE');
  final TextEditingController _tarifa = TextEditingController();

  DateTime? _fecha;

  bool _guardando = false;
  String? _error;

  String? _validacion;

  @override
  void dispose() {
    _placa.dispose();
    _tipo.dispose();
    _tarifa.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy,
      firstDate: DateTime(hoy.year - 5),
      lastDate: hoy,
      helpText: 'Fecha de la planilla',
    );
    if (elegida == null || !mounted) return;
    setState(() {
      _fecha = elegida;
      _validacion = null;
    });
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final formularioValido = _formKey.currentState?.validate() == true;

    if (_fecha == null) {
      setState(() {
        _validacion = 'Elige la fecha de la planilla.';
        _error = null;
      });
      return;
    }
    if (!formularioValido) return;

    setState(() {
      _guardando = true;
      _error = null;
      _validacion = null;
    });
    try {
      final planilla = Planilla(
        fecha: _fecha,
        placaVehiculo: _placa.text.trim().toUpperCase(),
        tipo: _tipo.text.trim(),
        tarifaId: int.parse(_tarifa.text.trim()),
      );
      final guardada = await widget.api.crear(planilla);
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
      title: const Text('Nueva planilla'),
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
                  'La planilla queda ACTIVA y PENDIENTE de pago; el número, '
                  'la hora y el valor los calcula el backend. Si el conductor '
                  'tiene una sanción activa que cubre la fecha, se rechaza.',
                  style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                CampoFecha(
                  etiqueta: 'Fecha de la planilla',
                  valor: _fecha,
                  habilitado: !_guardando,
                  onElegir: _elegirFecha,
                  onLimpiar: () => setState(() => _fecha = null),
                ),
                if (_validacion != null) AvisoFormulario(_validacion!),
                CustomTextField(
                  controller: _placa,
                  label: 'Vehículo',
                  hintText: 'Placa, ej. BRU001',
                  textCapitalization: TextCapitalization.characters,
                  enabled: !_guardando,
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Escribe la placa del vehículo.'
                      : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _tipo,
                  label: 'Tipo',
                  hintText: 'Ej. VIAJE',
                  textCapitalization: TextCapitalization.characters,
                  enabled: !_guardando,
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Escribe el tipo de planilla.'
                      : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _tarifa,
                  label: 'Tarifa (ID)',
                  hintText: 'Ej. 3',
                  keyboardType: TextInputType.number,
                  enabled: !_guardando,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (valor) {
                    final id = int.tryParse(valor?.trim() ?? '');
                    if (id == null) return 'Escribe el ID de la tarifa.';
                    return id <= 0
                        ? 'El ID de la tarifa debe ser mayor que cero.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                if (_error != null) AvisoFormulario(_error!),
                PrimaryButton(
                  label: 'Registrar planilla',
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
