import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/tarifa/tarifa.dart';
import '../services/remote/api_service.dart';
import '../services/remote/tarifas_api.dart';
import '../utils/api_error_message.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/fields/custom_text_field.dart';
import '../widgets/forms/form_fields.dart';

class FormularioTarifaScreen extends StatefulWidget {
  const FormularioTarifaScreen({required this.api, super.key});

  final TarifasApi api;

  @override
  State<FormularioTarifaScreen> createState() => _FormularioTarifaScreenState();
}

class _FormularioTarifaScreenState extends State<FormularioTarifaScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _aportesGastosVarios = TextEditingController();
  final TextEditingController _fondoReposicion = TextEditingController();
  final TextEditingController _aporteSocialSocio = TextEditingController();

  bool _activo = true;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _aportesGastosVarios.dispose();
    _fondoReposicion.dispose();
    _aporteSocialSocio.dispose();
    super.dispose();
  }

  double? _monto(String texto) {
    final limpio = texto.trim().replaceAll('.', '').replaceAll(',', '.');
    if (limpio.isEmpty) return null;
    final valor = double.tryParse(limpio);
    if (valor == null || valor < 0) return null;
    return valor;
  }

  String? _validarMonto(String? valor, String mensaje) =>
      _monto(valor ?? '') == null ? mensaje : null;

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final tarifa = Tarifa(
        aportesGastosVarios: _monto(_aportesGastosVarios.text)!,
        fondoReposicion: _monto(_fondoReposicion.text)!,
        aporteSocialSocio: _monto(_aporteSocialSocio.text)!,
        activo: _activo,
      );
      final guardada = await widget.api.crear(tarifa);
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
      title: const Text('Nueva tarifa'),
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
                  'El total lo calcula el backend sumando los tres conceptos. '
                  'La tarifa no se puede editar después: si un valor cambia, '
                  'inactívala y registra otra.',
                  style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _aportesGastosVarios,
                  label: 'Aportes y gastos varios',
                  hintText: 'Ej. 2500',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  enabled: !_guardando,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: (valor) => _validarMonto(
                    valor,
                    'Escribe el monto de aportes y gastos varios.',
                  ),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _fondoReposicion,
                  label: 'Fondo de reposición',
                  hintText: 'Ej. 1000',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  enabled: !_guardando,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: (valor) =>
                      _validarMonto(valor, 'Escribe el fondo de reposición.'),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _aporteSocialSocio,
                  label: 'Aporte social del socio',
                  hintText: 'Ej. 500',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  enabled: !_guardando,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: (valor) => _validarMonto(
                    valor,
                    'Escribe el aporte social del socio.',
                  ),
                ),
                const SizedBox(height: 8),
                CampoActivo(
                  etiqueta: 'Tarifa activa',
                  valor: _activo,
                  habilitado: !_guardando,
                  onChanged: (valor) => setState(() => _activo = valor),
                ),
                const SizedBox(height: 8),
                if (_error != null) AvisoFormulario(_error!),
                PrimaryButton(
                  label: 'Registrar tarifa',
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
