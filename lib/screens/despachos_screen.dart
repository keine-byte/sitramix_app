import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/common/page_query.dart';
import '../models/despacho/despacho.dart';
import '../services/remote/api_service.dart';
import '../services/remote/despachos_api.dart';
import '../utils/api_error_message.dart';
import '../utils/fechas.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/data_rows.dart';
import '../widgets/fields/custom_text_field.dart';
import 'formulario_despacho_screen.dart';

class DespachosScreen extends StatefulWidget {
  const DespachosScreen({required this.api, super.key});

  final DespachosApi api;

  @override
  State<DespachosScreen> createState() => _DespachosScreenState();
}

class _DespachosScreenState extends State<DespachosScreen> {
  static const int _pageSize = 20;

  final TextEditingController _vehiculoController = TextEditingController();
  final TextEditingController _rutaController = TextEditingController();

  final List<Despacho> _despachos = <Despacho>[];

  DateTime? _fecha;
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
    _vehiculoController.dispose();
    _rutaController.dispose();
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
        vehiculo: _vehiculoController.text.trim(),
        ruta: _rutaController.text.trim(),
        fecha: _fecha,
      );
      if (!mounted) return;
      setState(() {
        if (reiniciar) _despachos.clear();
        _despachos.addAll(resultado);
        _hayMas = query.hasNext(resultado.length);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      final mensaje = mensajeDeApi(error);
      setState(() => _error = mensaje);
      if (_despachos.isNotEmpty) _mostrarMensaje(mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    var inicial = _fecha ?? hoy;
    if (inicial.isAfter(hoy)) inicial = hoy;

    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2000),
      lastDate: hoy,
      helpText: 'Despachos del día',
    );
    if (elegida == null || !mounted) return;
    setState(() => _fecha = elegida);
    await _consultar();
  }

  void _quitarFecha() {
    setState(() => _fecha = null);
    _consultar();
  }

  void _limpiarFiltros() {
    _vehiculoController.clear();
    _rutaController.clear();
    setState(() => _fecha = null);
    _consultar();
  }

  Future<void> _abrirDetalle(Despacho despacho) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleDespacho(
        despacho: despacho,
        api: widget.api,
        onCancelado: _consultar,
      ),
    );
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _abrirFormulario() async {
    final guardado = await Navigator.of(context).push<Despacho>(
      MaterialPageRoute<Despacho>(
        builder: (_) => FormularioDespachoScreen(api: widget.api),
      ),
    );
    if (guardado == null || !mounted) return;
    _mostrarMensaje(
      guardado.id == null
          ? 'Despacho registrado.'
          : 'Despacho #${guardado.id} registrado.',
    );
    await _consultar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Despachos'),
      titleTextStyle: const TextStyle(
        color: AppTheme.secondary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      actions: [
        IconButton(
          tooltip: 'Nuevo despacho',
          onPressed: _abrirFormulario,
          icon: const Icon(Icons.add_road_rounded),
        ),
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
          controller: _vehiculoController,
          label: 'Vehículo',
          hintText: 'Placa',
          onFieldSubmitted: (_) => _consultar(),
        ),
        const SizedBox(height: 10),
        CustomTextField(
          controller: _rutaController,
          label: 'Ruta',
          hintText: 'Destino',
          textInputAction: TextInputAction.search,
          onFieldSubmitted: (_) => _consultar(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _cargando ? null : _elegirFecha,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(
                _fecha == null ? 'Fecha' : 'Fecha ${formatearFecha(_fecha)}',
              ),
            ),
            if (_fecha != null)
              TextButton(
                onPressed: _cargando ? null : _quitarFecha,
                child: const Text('Quitar fecha'),
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
    if (_cargando && _despachos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_despachos.isEmpty) {
      return _error != null ? _vistaError() : _vistaVacia();
    }
    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _despachos.length + (_hayMas ? 1 : 0),
        itemBuilder: (context, index) => index >= _despachos.length
            ? _botonCargarMas()
            : _tarjeta(_despachos[index]),
      ),
    );
  }

  Widget _vistaVacia() => _mensaje(
    icon: Icons.route_outlined,
    titulo: 'Sin despachos',
    detalle: 'No hay despachos para estos filtros.',
    accion: TextButton(
      onPressed: _limpiarFiltros,
      child: const Text('Limpiar filtros'),
    ),
  );

  Widget _vistaError() => _mensaje(
    icon: Icons.cloud_off_rounded,
    titulo: 'No se pudieron cargar los despachos',
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

  Widget _tarjeta(Despacho despacho) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
    child: InkWell(
      onTap: () => _abrirDetalle(despacho),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _titulo(despacho),
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
                  despacho.estado.apiValue,
                  color: despacho.estaCancelado
                      ? const Color(0xFF77798B)
                      : const Color(0xFF1F9D55),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DatoFila(
              Icons.route_rounded,
              despacho.ruta.isEmpty ? 'Sin ruta' : despacho.ruta,
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.directions_bus_rounded,
              despacho.placaVehiculo.isEmpty
                  ? 'Sin vehículo'
                  : despacho.placaVehiculo,
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.groups_rounded,
              '${despacho.numeroPasajeros} pasajeros',
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.schedule_rounded,
              '${formatearFecha(despacho.fecha, vacio: 'sin fecha')} · '
              '${despacho.hora ?? '--:--:--'}',
            ),
          ],
        ),
      ),
    ),
  );
}

String _titulo(Despacho despacho) =>
    despacho.id == null ? 'Despacho' : 'Despacho #${despacho.id}';

class _DetalleDespacho extends StatefulWidget {
  const _DetalleDespacho({
    required this.despacho,
    required this.api,
    required this.onCancelado,
  });

  final Despacho despacho;
  final DespachosApi api;

  final VoidCallback onCancelado;

  @override
  State<_DetalleDespacho> createState() => _DetalleDespachoState();
}

class _DetalleDespachoState extends State<_DetalleDespacho> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _motivoController = TextEditingController();

  late Despacho _despacho = widget.despacho;

  bool _cargando = false;
  bool _cancelando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_despacho.id != null) _refrescar();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _refrescar() async {
    final id = _despacho.id;
    if (id == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final detalle = await widget.api.consultar(id);
      if (!mounted) return;
      setState(() => _despacho = detalle);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cancelar() async {
    final id = _despacho.id;
    if (id == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar despacho'),
        content: Text(
          'El despacho #$id quedará en CANCELADO con el motivo indicado. El '
          'registro no se borra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar despacho'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() {
      _cancelando = true;
      _error = null;
    });
    try {
      final resultado = await widget.api.cancelar(
        id,
        motivo: _motivoController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _despacho = resultado);
      widget.onCancelado();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final despacho = _despacho;
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
                      _titulo(despacho),
                      style: const TextStyle(
                        color: AppTheme.secondary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Etiqueta(
                    despacho.estado.apiValue,
                    color: despacho.estaCancelado
                        ? const Color(0xFF77798B)
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
                  habilitado: !_cargando && !_cancelando,
                ),
              ],
              const SizedBox(height: 16),
              CampoDetalle(Icons.route_rounded, 'Ruta', despacho.ruta),
              CampoDetalle(
                Icons.directions_bus_rounded,
                'Vehículo',
                despacho.placaVehiculo,
              ),
              CampoDetalle(
                Icons.groups_rounded,
                'Pasajeros',
                '${despacho.numeroPasajeros}',
              ),
              CampoDetalle(
                Icons.event_available_rounded,
                'Fecha',
                formatearFecha(despacho.fecha),
              ),
              CampoDetalle(Icons.schedule_rounded, 'Hora', despacho.hora),
              CampoDetalle(
                Icons.badge_rounded,
                'Registrado por',
                despacho.registradoPor,
              ),
              CampoDetalle(
                Icons.history_rounded,
                'Fecha de registro',
                formatearFecha(despacho.fechaRegistro),
              ),
              if (despacho.estaCancelado) ...[
                const Divider(height: 24),
                CampoDetalle(
                  Icons.event_busy_rounded,
                  'Fecha de cancelación',
                  formatearFecha(despacho.fechaCancelacion),
                ),
                CampoDetalle(
                  Icons.person_off_rounded,
                  'Cancelado por',
                  despacho.canceladoPor,
                ),
                CampoDetalle(
                  Icons.notes_rounded,
                  'Motivo de cancelación',
                  despacho.motivoCancelacion,
                ),
                const Text(
                  'El despacho ya está cancelado.',
                  style: TextStyle(color: Color(0xFF77798B)),
                ),
              ] else ...<Widget>[
                const Divider(height: 24),
                CustomTextField(
                  controller: _motivoController,
                  label: 'Motivo de cancelación',
                  hintText: 'Máximo 250 caracteres',
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(250),
                  ],
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Escribe el motivo de la cancelación'
                      : null,
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Cancelar despacho',
                  icon: Icons.cancel_rounded,
                  isLoading: _cancelando,
                  onPressed: _cargando || _cancelando ? null : _cancelar,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
