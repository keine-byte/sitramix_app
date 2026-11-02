import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/despacho/despacho.dart';
import '../services/remote/api_service.dart';
import '../services/remote/despachos_api.dart';
import '../utils/api_error_message.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/fields/custom_text_field.dart';
import '../widgets/forms/form_fields.dart';

class FormularioDespachoScreen extends StatefulWidget {
  const FormularioDespachoScreen({required this.api, super.key});

  final DespachosApi api;

  @override
  State<FormularioDespachoScreen> createState() =>
      _FormularioDespachoScreenState();
}

class _FormularioDespachoScreenState extends State<FormularioDespachoScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _ruta = TextEditingController();
  final TextEditingController _placa = TextEditingController();
  final TextEditingController _pasajeros = TextEditingController();

  DateTime? _fecha;
  TimeOfDay? _hora;

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _ruta.dispose();
    _placa.dispose();
    _pasajeros.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1),
      helpText: 'Fecha del despacho',
    );
    if (elegida == null || !mounted) return;
    setState(() => _fecha = elegida);
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
      helpText: 'Hora del despacho',
    );
    if (elegida == null || !mounted) return;
    setState(() => _hora = elegida);
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final despacho = Despacho(
        ruta: _ruta.text.trim(),
        placaVehiculo: _placa.text.trim().toUpperCase(),
        numeroPasajeros: int.parse(_pasajeros.text.trim()),
        fecha: _fecha,
        hora: _hora == null ? null : horaApi(_hora!),
      );
      final guardado = await widget.api.crear(despacho);
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
      title: const Text('Nuevo despacho'),
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
                  'El despacho queda en estado REGISTRADO. Para anularlo hay '
                  'que cancelarlo con un motivo desde el detalle.',
                  style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _ruta,
                  label: 'Ruta',
                  hintText: 'Ej. Centro - Terminal',
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !_guardando,
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Escribe la ruta.'
                      : null,
                ),
                const SizedBox(height: 12),
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
                  controller: _pasajeros,
                  label: 'Número de pasajeros',
                  hintText: 'Ej. 24',
                  keyboardType: TextInputType.number,
                  enabled: !_guardando,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (valor) {
                    final cantidad = int.tryParse(valor?.trim() ?? '');
                    if (cantidad == null) {
                      return 'Escribe el número de pasajeros.';
                    }
                    return cantidad <= 0 ? 'Debe ser mayor que cero.' : null;
                  },
                ),
                const SizedBox(height: 4),
                CampoFecha(
                  etiqueta: 'Fecha del despacho',
                  valor: _fecha,
                  habilitado: !_guardando,
                  onElegir: _elegirFecha,
                  onLimpiar: () => setState(() => _fecha = null),
                ),
                CampoHora(
                  etiqueta: 'Hora del despacho',
                  valor: _hora,
                  habilitado: !_guardando,
                  onElegir: _elegirHora,
                  onLimpiar: () => setState(() => _hora = null),
                ),
                const Text(
                  'Si dejas la fecha o la hora vacías, el backend usa el '
                  'momento del registro.',
                  style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_error != null) AvisoFormulario(_error!),
                PrimaryButton(
                  label: 'Registrar despacho',
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
