import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/pago/pago.dart';
import '../services/remote/api_service.dart';
import '../services/remote/pagos_api.dart';
import '../utils/api_error_message.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/fields/custom_text_field.dart';
import '../widgets/forms/form_fields.dart';

class FormularioPagoScreen extends StatefulWidget {
  const FormularioPagoScreen({required this.api, super.key});

  final PagosApi api;

  @override
  State<FormularioPagoScreen> createState() => _FormularioPagoScreenState();
}

class _FormularioPagoScreenState extends State<FormularioPagoScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _planilla = TextEditingController();

  DateTime? _fechaPago;

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _planilla.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaPago ?? hoy,
      firstDate: DateTime(hoy.year - 5),
      lastDate: hoy,
      helpText: 'Fecha de pago',
    );
    if (elegida == null || !mounted) return;
    setState(() => _fechaPago = elegida);
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final pago = Pago(
        numeroPlanilla: int.parse(_planilla.text.trim()),
        fechaPago: _fechaPago,
      );
      final guardado = await widget.api.registrar(pago);
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
      title: const Text('Registrar pago'),
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
                  'El pago debe corresponder a una planilla registrada. El valor '
                  'lo calcula el backend a partir de la tarifa de la planilla y '
                  'el pago no cambia su estado operativo.',
                  style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _planilla,
                  label: 'Número de planilla',
                  hintText: 'Ej. 1234',
                  keyboardType: TextInputType.number,
                  enabled: !_guardando,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (valor) {
                    final numero = int.tryParse(valor?.trim() ?? '');
                    if (numero == null) {
                      return 'Escribe el número de la planilla.';
                    }
                    return numero <= 0
                        ? 'El número debe ser mayor que cero.'
                        : null;
                  },
                ),
                const SizedBox(height: 4),
                CampoFecha(
                  etiqueta: 'Fecha de pago',
                  valor: _fechaPago,
                  habilitado: !_guardando,
                  onElegir: _elegirFecha,
                  onLimpiar: () => setState(() => _fechaPago = null),
                ),
                const Text(
                  'Si dejas la fecha vacía, el backend usa la fecha del '
                  'registro.',
                  style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_error != null) AvisoFormulario(_error!),
                PrimaryButton(
                  label: 'Registrar pago',
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
