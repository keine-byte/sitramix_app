import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/planilla/planilla.dart';
import '../services/remote/api_service.dart';
import '../services/remote/planillas_api.dart';
import '../utils/api_error_message.dart';
import '../utils/fechas.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/data_rows.dart';
import '../widgets/fields/custom_text_field.dart';

class PlanillaMasivaScreen extends StatefulWidget {
  const PlanillaMasivaScreen({required this.api, super.key});

  final PlanillasApi api;

  @override
  State<PlanillaMasivaScreen> createState() => _PlanillaMasivaScreenState();
}

class _PlanillaMasivaScreenState extends State<PlanillaMasivaScreen> {
  final TextEditingController _placaController = TextEditingController();
  final TextEditingController _tipoController = TextEditingController(
    text: 'VIAJE',
  );
  final TextEditingController _tarifaController = TextEditingController();

  final List<String> _placas = <String>[];

  DateTime? _fecha;
  InformePlanillasMasivas? _informe;
  bool _enviando = false;
  String? _error;

  String? _validacion;

  @override
  void dispose() {
    _placaController.dispose();
    _tipoController.dispose();
    _tarifaController.dispose();
    super.dispose();
  }

  void _agregarPlaca() {
    final placa = _placaController.text.trim().toUpperCase();
    if (placa.isEmpty) {
      _mostrarMensaje('Escribe la placa del vehículo.');
      return;
    }
    if (_placas.contains(placa)) {
      _mostrarMensaje('Esa placa ya está en la lista.');
      return;
    }
    setState(() {
      _placas.add(placa);
      _placaController.clear();
      _error = null;
      _validacion = null;
    });
  }

  void _quitarPlaca(String placa) {
    setState(() {
      _placas.remove(placa);
      _error = null;
    });
  }

  void _validar(String mensaje) => setState(() {
    _validacion = mensaje;
    _error = null;
  });

  Future<void> _elegirFecha() async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    var inicial = _fecha ?? hoy;
    if (inicial.isAfter(hoy)) inicial = hoy;

    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2000),
      lastDate: hoy,
      helpText: 'Fecha de las planillas',
    );
    if (elegida == null || !mounted) return;
    setState(() {
      _fecha = elegida;
      _error = null;
      _validacion = null;
    });
  }

  Future<void> _registrar() async {
    FocusScope.of(context).unfocus();

    final fecha = _fecha;
    if (fecha == null) {
      _validar('Elige la fecha de las planillas.');
      return;
    }
    if (_placas.isEmpty) {
      _validar('Agrega al menos una placa.');
      return;
    }
    final tipo = _tipoController.text.trim();
    if (tipo.isEmpty) {
      _validar('Escribe el tipo de planilla (por ejemplo VIAJE).');
      return;
    }
    final tarifaId = int.tryParse(_tarifaController.text.trim());
    if (tarifaId == null || tarifaId <= 0) {
      _validar('Escribe el ID de la tarifa (número).');
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
      _informe = null;
      _validacion = null;
    });
    try {
      final informe = await widget.api.crearMasivas(
        PlanillaMasivaRequest(
          fecha: fecha,
          placasVehiculos: List<String>.of(_placas),
          tipo: tipo,
          tarifaId: tarifaId,
        ),
      );
      if (!mounted) return;
      setState(() => _informe = informe);
      _mostrarMensaje(
        informe.totalRegistradas == 1
            ? 'Se registró 1 planilla.'
            : 'Se registraron ${informe.totalRegistradas} planillas.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Planillas masivas'),
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const Text(
                'Registra la misma planilla para varias placas. Las placas '
                'válidas se registran aunque otras se rechacen.',
                style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
              ),
              const SizedBox(height: 12),
              _formulario(),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                AvisoAccion(
                  _error!,
                  onAccion: _registrar,
                  habilitado: !_enviando,
                ),
              ],
              if (_informe != null) ...<Widget>[
                const SizedBox(height: 20),
                _detalleInforme(_informe!),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _formulario() => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _enviando ? null : _elegirFecha,
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(
              _fecha == null
                  ? 'Elegir fecha'
                  : 'Fecha ${formatearFecha(_fecha)}',
            ),
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _tipoController,
            label: 'Tipo',
            hintText: 'Ej. VIAJE',
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _tarifaController,
            label: 'Tarifa (ID)',
            hintText: 'Ej. 3',
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _placaController,
                  label: 'Placa',
                  hintText: 'Ej. BRU001',
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _agregarPlaca(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _enviando ? null : _agregarPlaca,
                child: const Text('Agregar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_placas.isEmpty)
            const Text(
              'Aún no agregas placas.',
              style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final placa in _placas)
                  InputChip(
                    label: Text(placa),
                    deleteButtonTooltipMessage: 'Quitar $placa',
                    onDeleted: _enviando ? null : () => _quitarPlaca(placa),
                  ),
              ],
            ),
          if (_validacion != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _validacion!,
              style: const TextStyle(color: Color(0xFF8A1C1C), fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Registrar planillas',
            icon: Icons.playlist_add_check_rounded,
            isLoading: _enviando,
            onPressed: _enviando ? null : _registrar,
          ),
        ],
      ),
    ),
  );

  Widget _detalleInforme(InformePlanillasMasivas informe) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informe de la carga',
            style: TextStyle(
              color: AppTheme.secondary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          CampoDetalle(
            Icons.list_alt_rounded,
            'Solicitadas',
            '${informe.totalSolicitadas}',
          ),
          CampoDetalle(
            Icons.task_alt_rounded,
            'Registradas',
            '${informe.totalRegistradas}',
          ),
          CampoDetalle(
            Icons.report_problem_rounded,
            'Rechazadas',
            '${informe.totalRechazadas}',
          ),
          if (!informe.esCoherente)
            const Text(
              'Los totales no cuadran: revisa las planillas registradas.',
              style: TextStyle(color: Color(0xFF8A1C1C), fontSize: 12),
            ),
          if (informe.correctas.isNotEmpty) ...<Widget>[
            const Divider(height: 24),
            const Text(
              'Planillas registradas',
              style: TextStyle(
                color: AppTheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final planilla in informe.correctas)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DatoFila(
                  Icons.receipt_long_rounded,
                  '#${planilla.numero ?? '—'} · '
                  '${planilla.placaVehiculo ?? 'Sin placa'}',
                ),
              ),
          ],
          if (informe.rechazadas.isNotEmpty) ...<Widget>[
            const Divider(height: 24),
            const Text(
              'Placas rechazadas',
              style: TextStyle(
                color: AppTheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final rechazo in informe.rechazadas)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DatoFila(
                  Icons.block_rounded,
                  '${rechazo.placaVehiculo} · ${rechazo.codigo} · '
                  '${rechazo.motivo}',
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
