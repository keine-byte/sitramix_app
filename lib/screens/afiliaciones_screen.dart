import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/afiliacion/afiliacion.dart';
import '../models/common/page_query.dart';
import '../services/remote/afiliaciones_api.dart';
import '../services/remote/api_service.dart';
import '../utils/api_error_message.dart';
import '../utils/fechas.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/data_rows.dart';
import '../widgets/fields/custom_text_field.dart';

class AfiliacionesScreen extends StatefulWidget {
  const AfiliacionesScreen({required this.api, super.key});

  final AfiliacionesApi api;

  @override
  State<AfiliacionesScreen> createState() => _AfiliacionesScreenState();
}

class _AfiliacionesScreenState extends State<AfiliacionesScreen> {
  static const int _pageSize = 20;

  final TextEditingController _asociadoController = TextEditingController();
  final TextEditingController _vehiculoController = TextEditingController();

  final List<Afiliacion> _afiliaciones = <Afiliacion>[];

  EstadoAfiliacion? _estado;
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
    _asociadoController.dispose();
    _vehiculoController.dispose();
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
        asociado: _asociadoController.text.trim(),
        vehiculo: _vehiculoController.text.trim(),
        estado: _estado,
      );
      if (!mounted) return;
      setState(() {
        if (reiniciar) _afiliaciones.clear();
        _afiliaciones.addAll(resultado);
        _hayMas = query.hasNext(resultado.length);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      final mensaje = mensajeDeApi(error);
      setState(() => _error = mensaje);
      if (_afiliaciones.isNotEmpty) _mostrarMensaje(mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarEstado(EstadoAfiliacion? estado) {
    if (_estado == estado) return;
    setState(() => _estado = estado);
    _consultar();
  }

  void _limpiarFiltros() {
    _asociadoController.clear();
    _vehiculoController.clear();
    setState(() => _estado = null);
    _consultar();
  }

  Future<void> _abrirDetalle(Afiliacion afiliacion) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleAfiliacion(
        afiliacion: afiliacion,
        api: widget.api,
        onFinalizada: _consultar,
      ),
    );
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Afiliaciones'),
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
          controller: _asociadoController,
          label: 'Asociado',
          hintText: 'Identificación',
          onFieldSubmitted: (_) => _consultar(),
        ),
        const SizedBox(height: 10),
        CustomTextField(
          controller: _vehiculoController,
          label: 'Vehículo',
          hintText: 'Placa',
          textInputAction: TextInputAction.search,
          onFieldSubmitted: (_) => _consultar(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Todas'),
              selected: _estado == null,
              onSelected: (_) => _cambiarEstado(null),
            ),
            ChoiceChip(
              label: const Text('Activas'),
              selected: _estado == EstadoAfiliacion.activa,
              onSelected: (_) => _cambiarEstado(EstadoAfiliacion.activa),
            ),
            ChoiceChip(
              label: const Text('Finalizadas'),
              selected: _estado == EstadoAfiliacion.finalizada,
              onSelected: (_) => _cambiarEstado(EstadoAfiliacion.finalizada),
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
    if (_cargando && _afiliaciones.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_afiliaciones.isEmpty) {
      return _error != null ? _vistaError() : _vistaVacia();
    }
    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _afiliaciones.length + (_hayMas ? 1 : 0),
        itemBuilder: (context, index) => index >= _afiliaciones.length
            ? _botonCargarMas()
            : _tarjeta(_afiliaciones[index]),
      ),
    );
  }

  Widget _vistaVacia() => _mensaje(
    icon: Icons.link_off_rounded,
    titulo: 'Sin afiliaciones',
    detalle: 'No hay afiliaciones para estos filtros.',
    accion: TextButton(
      onPressed: _limpiarFiltros,
      child: const Text('Limpiar filtros'),
    ),
  );

  Widget _vistaError() => _mensaje(
    icon: Icons.cloud_off_rounded,
    titulo: 'No se pudieron cargar las afiliaciones',
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

  Widget _tarjeta(Afiliacion afiliacion) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
    child: InkWell(
      onTap: () => _abrirDetalle(afiliacion),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _titulo(afiliacion),
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
                  afiliacion.estado.apiValue,
                  color: afiliacion.estaActiva
                      ? const Color(0xFF1F9D55)
                      : const Color(0xFF77798B),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DatoFila(
              Icons.person_rounded,
              afiliacion.identificacionAsociado.isEmpty
                  ? 'Sin asociado'
                  : afiliacion.identificacionAsociado,
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.directions_bus_rounded,
              afiliacion.placaVehiculo.isEmpty
                  ? 'Sin vehículo'
                  : afiliacion.placaVehiculo,
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.event_available_rounded,
              'Desde '
              '${formatearFecha(afiliacion.fechaAfiliacion, vacio: 'sin registrar')}',
            ),
            if (afiliacion.fechaFinAfiliacion != null) ...[
              const SizedBox(height: 6),
              DatoFila(
                Icons.event_busy_rounded,
                'Hasta ${formatearFecha(afiliacion.fechaFinAfiliacion)}',
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

String _titulo(Afiliacion afiliacion) =>
    afiliacion.id == null ? 'Afiliación' : 'Afiliación #${afiliacion.id}';

class _DetalleAfiliacion extends StatefulWidget {
  const _DetalleAfiliacion({
    required this.afiliacion,
    required this.api,
    required this.onFinalizada,
  });

  final Afiliacion afiliacion;
  final AfiliacionesApi api;

  final VoidCallback onFinalizada;

  @override
  State<_DetalleAfiliacion> createState() => _DetalleAfiliacionState();
}

class _DetalleAfiliacionState extends State<_DetalleAfiliacion> {
  late Afiliacion _afiliacion = widget.afiliacion;

  bool _cargando = false;
  bool _finalizando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_afiliacion.id != null) _refrescar();
  }

  Future<void> _refrescar() async {
    final id = _afiliacion.id;
    if (id == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final detalle = await widget.api.consultar(id);
      if (!mounted) return;
      setState(() => _afiliacion = detalle);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _finalizar() async {
    final id = _afiliacion.id;
    if (id == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar afiliación'),
        content: Text(
          'Se finalizará la afiliación #$id: el vehículo quedará sin una '
          'afiliación activa. La fecha de fin la asigna el backend (hoy, hora '
          'de Bogotá).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() {
      _finalizando = true;
      _error = null;
    });
    try {
      final resultado = await widget.api.finalizar(id);
      if (!mounted) return;
      setState(() => _afiliacion = resultado);
      widget.onFinalizada();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _finalizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final afiliacion = _afiliacion;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _titulo(afiliacion),
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Etiqueta(
                  afiliacion.estado.apiValue,
                  color: afiliacion.estaActiva
                      ? const Color(0xFF1F9D55)
                      : const Color(0xFF77798B),
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
                habilitado: !_cargando && !_finalizando,
              ),
            ],
            const SizedBox(height: 16),
            CampoDetalle(
              Icons.person_rounded,
              'Asociado',
              afiliacion.identificacionAsociado,
            ),
            CampoDetalle(
              Icons.directions_bus_rounded,
              'Vehículo',
              afiliacion.placaVehiculo,
            ),
            CampoDetalle(
              Icons.event_available_rounded,
              'Fecha de afiliación',
              formatearFecha(afiliacion.fechaAfiliacion),
            ),
            CampoDetalle(
              Icons.event_busy_rounded,
              'Fecha de fin',
              afiliacion.fechaFinAfiliacion == null
                  ? 'Vigente'
                  : formatearFecha(afiliacion.fechaFinAfiliacion),
            ),
            CampoDetalle(
              Icons.flag_rounded,
              'Estado',
              afiliacion.estado.apiValue,
            ),
            CampoDetalle(
              Icons.history_rounded,
              'Fecha de registro',
              formatearFecha(afiliacion.fechaRegistro),
            ),
            CampoDetalle(
              Icons.update_rounded,
              'Última actualización',
              formatearFecha(afiliacion.ultimaActualizacion),
            ),
            const SizedBox(height: 12),
            if (afiliacion.estaActiva)
              PrimaryButton(
                label: 'Finalizar afiliación',
                icon: Icons.link_off_rounded,
                isLoading: _finalizando,
                onPressed: _cargando || _finalizando ? null : _finalizar,
              )
            else
              const Text(
                'La afiliación ya está finalizada.',
                style: TextStyle(color: Color(0xFF77798B)),
              ),
          ],
        ),
      ),
    );
  }
}
