import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/vehiculo/vehiculo.dart';
import '../services/remote/api_service.dart';
import '../services/remote/vehiculos_api.dart';
import '../utils/api_error_message.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/fields/custom_text_field.dart';
import '../widgets/forms/form_fields.dart';

class FormularioVehiculoScreen extends StatefulWidget {
  const FormularioVehiculoScreen({required this.api, this.vehiculo, super.key});

  final VehiculosApi api;

  final Vehiculo? vehiculo;

  bool get esEdicion => vehiculo != null;

  @override
  State<FormularioVehiculoScreen> createState() =>
      _FormularioVehiculoScreenState();
}

class _FormularioVehiculoScreenState extends State<FormularioVehiculoScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _placa = TextEditingController(
    text: widget.vehiculo?.placa ?? '',
  );
  late final TextEditingController _tipo = TextEditingController(
    text: widget.vehiculo?.tipo ?? '',
  );
  late final TextEditingController _marca = TextEditingController(
    text: widget.vehiculo?.marca ?? '',
  );
  late final TextEditingController _modelo = TextEditingController(
    text: widget.vehiculo?.modelo ?? '',
  );
  late final TextEditingController _capacidad = TextEditingController(
    text: widget.vehiculo == null
        ? ''
        : '${widget.vehiculo!.capacidadPasajeros}',
  );
  late final TextEditingController _tarjetaPropiedad = TextEditingController(
    text: widget.vehiculo?.tarjetaPropiedad ?? '',
  );
  late final TextEditingController _tarifaId = TextEditingController(
    text: widget.vehiculo?.tarifaId == null
        ? ''
        : '${widget.vehiculo!.tarifaId}',
  );
  late final TextEditingController _identificacionConductor =
      TextEditingController(
        text: widget.vehiculo?.identificacionConductor ?? '',
      );

  late DateTime? _vigenciaSoat = widget.vehiculo?.vigenciaSoat;
  late DateTime? _vigenciaTrm = widget.vehiculo?.vigenciaTrm;
  late DateTime? _fechaIngreso = widget.vehiculo?.fechaIngreso;
  late bool _activo = widget.vehiculo?.activo ?? true;

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _placa.dispose();
    _tipo.dispose();
    _marca.dispose();
    _modelo.dispose();
    _capacidad.dispose();
    _tarjetaPropiedad.dispose();
    _tarifaId.dispose();
    _identificacionConductor.dispose();
    super.dispose();
  }

  Future<DateTime?> _pedirFecha({
    required DateTime? actual,
    required String ayuda,
    required DateTime inicial,
    DateTime? ultima,
  }) {
    final hoy = DateUtils.dateOnly(DateTime.now());
    return showDatePicker(
      context: context,
      initialDate: actual ?? inicial,
      firstDate: DateTime(1900),
      lastDate: ultima ?? hoy,
      helpText: ayuda,
    );
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final vehiculo = Vehiculo(
        placa: _placa.text.trim().toUpperCase(),
        tipo: _tipo.text.trim(),
        marca: _marca.text.trim(),
        modelo: _modelo.text.trim(),
        capacidadPasajeros: int.tryParse(_capacidad.text.trim()) ?? 0,
        tarjetaPropiedad: _tarjetaPropiedad.text.trim(),
        activo: _activo,
        tarifaId: int.tryParse(_tarifaId.text.trim()),
        vigenciaSoat: _vigenciaSoat,
        vigenciaTrm: _vigenciaTrm,
        fechaIngreso: _fechaIngreso,
        identificacionConductor: widget.esEdicion
            ? textoONull(_identificacionConductor.text)
            : null,
      );
      final guardado = widget.esEdicion
          ? await widget.api.actualizar(vehiculo)
          : await widget.api.crear(vehiculo);
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
  Widget build(BuildContext context) {
    final datosBloqueados = widget.esEdicion;
    final habilitado = !_guardando;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esEdicion ? 'Editar vehículo' : 'Nuevo vehículo'),
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
                  Text(
                    datosBloqueados
                        ? 'La placa y los datos del vehículo no se pueden '
                              'cambiar. Se actualizan la tarifa, el SOAT, el '
                              'TRM, la fecha de ingreso, el conductor y el '
                              'estado.'
                        : 'La placa identifica al vehículo: no se puede '
                              'cambiar después de crearlo.',
                    style: const TextStyle(
                      color: Color(0xFF77798B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _placa,
                    label: 'Placa',
                    hintText: 'Ej. BRU001',
                    enabled: !datosBloqueados && habilitado,
                    textCapitalization: TextCapitalization.characters,
                    validator: (valor) => valor == null || valor.trim().isEmpty
                        ? 'Escribe la placa.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _tipo,
                    label: 'Tipo',
                    hintText: 'Ej. BUS',
                    enabled: !datosBloqueados && habilitado,
                    validator: (valor) => valor == null || valor.trim().isEmpty
                        ? 'Escribe el tipo de vehículo.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _marca,
                    label: 'Marca',
                    hintText: 'Ej. Chevrolet',
                    enabled: !datosBloqueados && habilitado,
                    validator: (valor) => valor == null || valor.trim().isEmpty
                        ? 'Escribe la marca.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _modelo,
                    label: 'Modelo',
                    hintText: 'Ej. 2020',
                    enabled: !datosBloqueados && habilitado,
                    validator: (valor) => valor == null || valor.trim().isEmpty
                        ? 'Escribe el modelo.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _capacidad,
                    label: 'Capacidad de pasajeros',
                    hintText: 'Ej. 30',
                    keyboardType: TextInputType.number,
                    enabled: !datosBloqueados && habilitado,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (valor) {
                      final capacidad = int.tryParse(valor?.trim() ?? '');
                      if (capacidad == null || capacidad <= 0) {
                        return 'Escribe la capacidad de pasajeros.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _tarjetaPropiedad,
                    label: 'Tarjeta de propiedad',
                    hintText: 'Ej. TP-889900',
                    enabled: !datosBloqueados && habilitado,
                    validator: (valor) => valor == null || valor.trim().isEmpty
                        ? 'Escribe la tarjeta de propiedad.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _tarifaId,
                    label: 'Tarifa (ID)',
                    hintText: 'Ej. 3',
                    keyboardType: TextInputType.number,
                    enabled: habilitado,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 12),
                  CampoFecha(
                    etiqueta: 'Vigencia del SOAT',
                    valor: _vigenciaSoat,
                    habilitado: habilitado,
                    onElegir: () async {
                      final elegida = await _pedirFecha(
                        actual: _vigenciaSoat,
                        ayuda: 'Vigencia del SOAT',
                        inicial: DateTime.now(),
                        ultima: DateTime(DateTime.now().year + 20),
                      );
                      if (elegida == null || !mounted) return;
                      setState(() => _vigenciaSoat = elegida);
                    },
                    onLimpiar: () => setState(() => _vigenciaSoat = null),
                  ),
                  CampoFecha(
                    etiqueta: 'Vigencia del TRM',
                    valor: _vigenciaTrm,
                    habilitado: habilitado,
                    onElegir: () async {
                      final elegida = await _pedirFecha(
                        actual: _vigenciaTrm,
                        ayuda: 'Vigencia del TRM',
                        inicial: DateTime.now(),
                        ultima: DateTime(DateTime.now().year + 20),
                      );
                      if (elegida == null || !mounted) return;
                      setState(() => _vigenciaTrm = elegida);
                    },
                    onLimpiar: () => setState(() => _vigenciaTrm = null),
                  ),
                  CampoFecha(
                    etiqueta: 'Fecha de ingreso',
                    valor: _fechaIngreso,
                    habilitado: habilitado,
                    onElegir: () async {
                      final elegida = await _pedirFecha(
                        actual: _fechaIngreso,
                        ayuda: 'Fecha de ingreso',
                        inicial: DateUtils.dateOnly(DateTime.now()),
                      );
                      if (elegida == null || !mounted) return;
                      setState(() => _fechaIngreso = elegida);
                    },
                    onLimpiar: () => setState(() => _fechaIngreso = null),
                  ),
                  if (datosBloqueados) ...<Widget>[
                    CustomTextField(
                      controller: _identificacionConductor,
                      label: 'Identificación del conductor',
                      hintText: 'Ej. 1098765432',
                      enabled: habilitado,
                    ),
                    const SizedBox(height: 12),
                  ],
                  CampoActivo(
                    etiqueta: 'Vehículo activo',
                    valor: _activo,
                    habilitado: habilitado,
                    onChanged: (valor) => setState(() => _activo = valor),
                  ),
                  const SizedBox(height: 8),
                  if (_error != null) AvisoFormulario(_error!),
                  PrimaryButton(
                    label: widget.esEdicion
                        ? 'Guardar cambios'
                        : 'Registrar vehículo',
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
}
