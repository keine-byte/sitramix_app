import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/common/page_query.dart';
import '../models/mantenimiento/mantenimiento.dart';
import '../services/remote/api_service.dart';
import '../services/remote/mantenimientos_api.dart';
import '../utils/api_error_message.dart';
import '../utils/fechas.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/data_rows.dart';
import '../widgets/fields/custom_text_field.dart';

class MantenimientosScreen extends StatefulWidget {
  const MantenimientosScreen({required this.api, super.key});

  final MantenimientosApi api;

  @override
  State<MantenimientosScreen> createState() => _MantenimientosScreenState();
}

class _MantenimientosScreenState extends State<MantenimientosScreen> {
  static const int _pageSize = 20;

  final TextEditingController _placaController = TextEditingController();

  final List<Mantenimiento> _mantenimientos = <Mantenimiento>[];

  DateTime? _desde;
  DateTime? _hasta;

  EstadoMantenimiento? _estado;
  int _page = 1;
  bool _hayMas = false;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  @override
  void dispose() {
    _placaController.dispose();
    super.dispose();
  }

  Future<void> _consultar() => _cargar(reiniciar: true);

  Future<void> _cargarMas() async {
    _page += 1;
    await _cargar(reiniciar: false);
  }

  Future<void> _cargar({required bool reiniciar}) async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
      if (reiniciar) _page = 1;
    });

    final query = PageQuery(page: _page, pageSize: _pageSize);
    try {
      final resultado = await widget.api.listar(
        query: query,
        placa: _placaController.text.trim(),
        estado: _estado,
        desde: _desde,
        hasta: _hasta,
      );
      if (!mounted) return;
      setState(() {
        if (reiniciar) _mantenimientos.clear();
        _mantenimientos.addAll(resultado);
        _hayMas = query.hasNext(resultado.length);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      final mensaje = mensajeDeApi(error);
      setState(() => _error = mensaje);
      if (_mantenimientos.isNotEmpty) _mostrarMensaje(mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarEstado(EstadoMantenimiento? estado) {
    if (_estado == estado) return;
    setState(() => _estado = estado);
    _consultar();
  }

  Future<void> _elegirFechaIngreso({required bool esDesde}) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final preferida = esDesde ? _desde : _hasta;
    var inicial = preferida ?? _desde ?? hoy;
    if (inicial.isAfter(hoy)) inicial = hoy;

    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2000),
      lastDate: hoy,
      helpText: esDesde ? 'Ingresos desde' : 'Ingresos hasta',
    );
    if (elegida == null || !mounted) return;

    setState(() {
      if (esDesde) {
        _desde = elegida;
        final hasta = _hasta;
        if (hasta != null && hasta.isBefore(elegida)) _hasta = null;
      } else {
        _hasta = elegida;
      }
    });
    await _consultar();
  }

  void _quitarFechas() {
    setState(() {
      _desde = null;
      _hasta = null;
    });
    _consultar();
  }

  void _limpiarFiltros() {
    _placaController.clear();
    setState(() {
      _estado = null;
      _desde = null;
      _hasta = null;
    });
    _consultar();
  }

  Future<void> _abrirDetalle(Mantenimiento mantenimiento) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleMantenimiento(
        mantenimiento: mantenimiento,
        api: widget.api,
        onFinalizado: _consultar,
      ),
    );
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mantenimientos'),
      titleTextStyle: const TextStyle(
        color: AppTheme.secondary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _cargando ? null : _consultar,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              _filtros(),
              Expanded(child: _contenido()),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _filtros() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _placaController,
          label: 'Vehículo',
          hintText: 'Placa',
          onFieldSubmitted: (_) => _consultar(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: _estado == null,
              onSelected: (_) => _cambiarEstado(null),
            ),
            ChoiceChip(
              label: const Text('En taller'),
              selected: _estado == EstadoMantenimiento.enMantenimiento,
              onSelected: (_) =>
                  _cambiarEstado(EstadoMantenimiento.enMantenimiento),
            ),
            ChoiceChip(
              label: const Text('Finalizados'),
              selected: _estado == EstadoMantenimiento.finalizado,
              onSelected: (_) => _cambiarEstado(EstadoMantenimiento.finalizado),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _cargando
                  ? null
                  : () => _elegirFechaIngreso(esDesde: true),
              icon: const Icon(Icons.event_available_rounded, size: 18),
              label: Text(
                _desde == null ? 'Desde' : 'Desde ${formatearFecha(_desde)}',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _cargando
                  ? null
                  : () => _elegirFechaIngreso(esDesde: false),
              icon: const Icon(Icons.event_busy_rounded, size: 18),
              label: Text(
                _hasta == null ? 'Hasta' : 'Hasta ${formatearFecha(_hasta)}',
              ),
            ),
            if (_desde != null || _hasta != null)
              TextButton(
                onPressed: _cargando ? null : _quitarFechas,
                child: const Text('Quitar fechas'),
              ),
            TextButton(
              onPressed: _cargando ? null : _consultar,
              child: const Text('Buscar'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _contenido() {
    if (_cargando && _mantenimientos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mantenimientos.isEmpty) {
      return _error != null ? _vistaError() : _vistaVacia();
    }
    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _mantenimientos.length + (_hayMas ? 1 : 0),
        itemBuilder: (context, index) => index >= _mantenimientos.length
            ? _botonCargarMas()
            : _tarjeta(_mantenimientos[index]),
      ),
    );
  }

  Widget _vistaVacia() => _mensaje(
    icon: Icons.build_circle_outlined,
    titulo: 'Sin mantenimientos',
    detalle: 'No hay mantenimientos para estos filtros.',
    accion: TextButton(
      onPressed: _limpiarFiltros,
      child: const Text('Limpiar filtros'),
    ),
  );

  Widget _vistaError() => _mensaje(
    icon: Icons.cloud_off_rounded,
    titulo: 'No se pudieron cargar los mantenimientos',
    detalle: _error ?? '',
    accion: TextButton(onPressed: _consultar, child: const Text('Reintentar')),
  );

  Widget _mensaje({
    required IconData icon,
    required String titulo,
    required String detalle,
    required Widget accion,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFFB9BCCB)),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.secondary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF77798B)),
          ),
          const SizedBox(height: 12),
          accion,
        ],
      ),
    ),
  );

  Widget _botonCargarMas() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: OutlinedButton(
      onPressed: _cargando ? null : _cargarMas,
      child: _cargando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Cargar más'),
    ),
  );

  Widget _tarjeta(Mantenimiento mantenimiento) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
    child: InkWell(
      onTap: () => _abrirDetalle(mantenimiento),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _titulo(mantenimiento),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Etiqueta(
                  mantenimiento.estado.apiValue,
                  color: mantenimiento.estaAbierto
                      ? const Color(0xFFB45309)
                      : const Color(0xFF1F9D55),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DatoFila(
              Icons.directions_bus_rounded,
              mantenimiento.placaVehiculo.isEmpty
                  ? 'Sin vehículo'
                  : mantenimiento.placaVehiculo,
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.build_rounded,
              mantenimiento.motivo == null || mantenimiento.motivo!.isEmpty
                  ? 'Sin motivo registrado'
                  : mantenimiento.motivo!,
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.event_available_rounded,
              'Ingreso '
              '${formatearFecha(mantenimiento.fechaIngreso, vacio: 'sin registrar')}',
            ),
            if (mantenimiento.fechaSalida != null) ...[
              const SizedBox(height: 6),
              DatoFila(
                Icons.event_busy_rounded,
                'Salida ${formatearFecha(mantenimiento.fechaSalida)}',
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

String _titulo(Mantenimiento mantenimiento) => mantenimiento.id == null
    ? 'Mantenimiento'
    : 'Mantenimiento #${mantenimiento.id}';

class _DetalleMantenimiento extends StatefulWidget {
  const _DetalleMantenimiento({
    required this.mantenimiento,
    required this.api,
    required this.onFinalizado,
  });

  final Mantenimiento mantenimiento;
  final MantenimientosApi api;

  final VoidCallback onFinalizado;

  @override
  State<_DetalleMantenimiento> createState() => _DetalleMantenimientoState();
}

class _DetalleMantenimientoState extends State<_DetalleMantenimiento> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _observacionesController =
      TextEditingController();

  late Mantenimiento _mantenimiento = widget.mantenimiento;
  late DateTime _fechaSalida = _conHoraActual(DateTime.now());

  bool _cargando = false;
  bool _registrando = false;
  String? _error;

  static DateTime _conHoraActual(DateTime dia) {
    final ahora = DateTime.now();
    return DateTime(dia.year, dia.month, dia.day, ahora.hour, ahora.minute);
  }

  @override
  void initState() {
    super.initState();
    if (_mantenimiento.id != null) _refrescar();
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _refrescar() async {
    final id = _mantenimiento.id;
    if (id == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final detalle = await widget.api.consultar(id);
      if (!mounted) return;
      setState(() => _mantenimiento = detalle);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirFechaSalida() async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(_fechaSalida),
      firstDate: DateTime(2000),
      lastDate: hoy,
      helpText: 'Fecha de salida',
    );
    if (elegida == null || !mounted) return;
    setState(() => _fechaSalida = _conHoraActual(elegida));
  }

  Future<void> _registrarSalida() async {
    final id = _mantenimiento.id;
    if (id == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salida del taller'),
        content: Text(
          'Se cerrará el mantenimiento de ${_mantenimiento.placaVehiculo} '
          'con fecha ${formatearFecha(_fechaSalida)}. Después podrá volver a '
          'generar planillas y despachos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() {
      _registrando = true;
      _error = null;
    });
    try {
      final resultado = await widget.api.registrarSalida(
        id,
        fechaSalida: _fechaSalida,
        observaciones: _observacionesController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _mantenimiento = resultado);
      widget.onFinalizado();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _registrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mantenimiento = _mantenimiento;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _titulo(mantenimiento),
                      style: const TextStyle(
                        color: AppTheme.secondary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Etiqueta(
                    mantenimiento.estado.apiValue,
                    color: mantenimiento.estaAbierto
                        ? const Color(0xFFB45309)
                        : const Color(0xFF1F9D55),
                  ),
                ],
              ),
              if (_cargando) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                AvisoAccion(
                  _error!,
                  onAccion: _refrescar,
                  habilitado: !_cargando && !_registrando,
                ),
              ],
              const SizedBox(height: 16),
              CampoDetalle(
                Icons.directions_bus_rounded,
                'Vehículo',
                mantenimiento.placaVehiculo,
              ),
              CampoDetalle(
                Icons.event_available_rounded,
                'Fecha de ingreso',
                formatearFecha(mantenimiento.fechaIngreso),
              ),
              CampoDetalle(
                Icons.event_busy_rounded,
                'Fecha de salida',
                mantenimiento.fechaSalida == null
                    ? 'Sin salida'
                    : formatearFecha(mantenimiento.fechaSalida),
              ),
              CampoDetalle(Icons.build_rounded, 'Motivo', mantenimiento.motivo),
              CampoDetalle(
                Icons.report_problem_rounded,
                'Estado al ingreso',
                mantenimiento.estadoVehiculoIngreso,
              ),
              CampoDetalle(
                Icons.notes_rounded,
                'Observaciones',
                mantenimiento.observaciones,
              ),
              const SizedBox(height: 6),
              if (mantenimiento.estaAbierto)
                ..._salida()
              else
                const Text(
                  'El vehículo ya salió del taller.',
                  style: TextStyle(color: Color(0xFF77798B)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _salida() => <Widget>[
    CustomTextField(
      controller: _observacionesController,
      label: 'Observaciones de la salida',
      hintText: 'Trabajo realizado, repuestos, etc.',
      validator: (valor) => valor == null || valor.trim().isEmpty
          ? 'Escribe las observaciones de la salida'
          : null,
    ),
    const SizedBox(height: 10),
    OutlinedButton.icon(
      onPressed: _registrando ? null : _elegirFechaSalida,
      icon: const Icon(Icons.event_rounded, size: 18),
      label: Text('Fecha de salida: ${formatearFecha(_fechaSalida)}'),
    ),
    const SizedBox(height: 12),
    PrimaryButton(
      label: 'Registrar salida',
      icon: Icons.build_circle_rounded,
      isLoading: _registrando,
      onPressed: _cargando || _registrando ? null : _registrarSalida,
    ),
  ];
}
