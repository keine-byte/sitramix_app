import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/common/page_query.dart';
import '../models/sancion/sancion.dart';
import '../services/remote/api_service.dart';
import '../services/remote/sanciones_api.dart';
import '../utils/api_error_message.dart';
import '../utils/fechas.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/data_rows.dart';
import '../widgets/fields/custom_text_field.dart';
import 'formulario_sancion_screen.dart';

class SancionesScreen extends StatefulWidget {
  const SancionesScreen({required this.api, super.key});

  final SancionesApi api;

  @override
  State<SancionesScreen> createState() => _SancionesScreenState();
}

class _SancionesScreenState extends State<SancionesScreen> {
  static const int _pageSize = 20;

  final TextEditingController _conductorController = TextEditingController();

  final List<Sancion> _sanciones = <Sancion>[];

  EstadoSancion? _estado;
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
    _conductorController.dispose();
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
        conductor: _conductorController.text.trim(),
        estado: _estado,
      );
      if (!mounted) return;
      setState(() {
        if (reiniciar) _sanciones.clear();
        _sanciones.addAll(resultado);
        _hayMas = query.hasNext(resultado.length);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      final mensaje = mensajeDeApi(error);
      setState(() => _error = mensaje);
      if (_sanciones.isNotEmpty) _mostrarMensaje(mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarEstado(EstadoSancion? estado) {
    if (_estado == estado) return;
    setState(() => _estado = estado);
    _consultar();
  }

  void _limpiarFiltros() {
    _conductorController.clear();
    setState(() => _estado = null);
    _consultar();
  }

  Future<void> _abrirDetalle(Sancion sancion) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleSancion(
        sancion: sancion,
        api: widget.api,
        onActualizada: _consultar,
      ),
    );
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _abrirFormulario() async {
    final guardada = await Navigator.of(context).push<Sancion>(
      MaterialPageRoute<Sancion>(
        builder: (_) => FormularioSancionScreen(api: widget.api),
      ),
    );
    if (guardada == null || !mounted) return;
    _mostrarMensaje(
      guardada.id == null
          ? 'Sanción registrada.'
          : 'Sanción #${guardada.id} registrada.',
    );
    await _consultar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sanciones'),
      titleTextStyle: const TextStyle(
        color: AppTheme.secondary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      actions: [
        IconButton(
          tooltip: 'Nueva sanción',
          onPressed: _abrirFormulario,
          icon: const Icon(Icons.add_alert_rounded),
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
          controller: _conductorController,
          label: 'Conductor',
          hintText: 'Identificación o nombres',
          textInputAction: TextInputAction.search,
          onFieldSubmitted: (_) => _consultar(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Todas'),
              selected: _estado == null,
              onSelected: (_) => _cambiarEstado(null),
            ),
            ChoiceChip(
              label: const Text('Activas'),
              selected: _estado == EstadoSancion.activa,
              onSelected: (_) => _cambiarEstado(EstadoSancion.activa),
            ),
            ChoiceChip(
              label: const Text('Cumplidas'),
              selected: _estado == EstadoSancion.cumplida,
              onSelected: (_) => _cambiarEstado(EstadoSancion.cumplida),
            ),
            ChoiceChip(
              label: const Text('Anuladas'),
              selected: _estado == EstadoSancion.anulada,
              onSelected: (_) => _cambiarEstado(EstadoSancion.anulada),
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
    if (_cargando && _sanciones.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sanciones.isEmpty) {
      return _error != null ? _vistaError() : _vistaVacia();
    }
    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _sanciones.length + (_hayMas ? 1 : 0),
        itemBuilder: (context, index) => index >= _sanciones.length
            ? _botonCargarMas()
            : _tarjeta(_sanciones[index]),
      ),
    );
  }

  Widget _vistaVacia() => _mensaje(
    icon: Icons.gavel_outlined,
    titulo: 'Sin sanciones',
    detalle: 'No hay sanciones para estos filtros.',
    accion: TextButton(
      onPressed: _limpiarFiltros,
      child: const Text('Limpiar filtros'),
    ),
  );

  Widget _vistaError() => _mensaje(
    icon: Icons.cloud_off_rounded,
    titulo: 'No se pudieron cargar las sanciones',
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

  Widget _tarjeta(Sancion sancion) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
    child: InkWell(
      onTap: () => _abrirDetalle(sancion),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _titulo(sancion),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (sancion.vigenteHoy) ...[
                  const Etiqueta('VIGENTE', color: Color(0xFFB45309)),
                  const SizedBox(width: 6),
                ],
                Etiqueta(
                  sancion.estado.apiValue,
                  color: _colorEstado(sancion.estado),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DatoFila(
              Icons.badge_rounded,
              sancion.nombresConductor == null ||
                      sancion.nombresConductor!.isEmpty
                  ? sancion.identificacionConductor
                  : '${sancion.nombresConductor} · '
                        '${sancion.identificacionConductor}',
            ),
            const SizedBox(height: 6),
            DatoFila(Icons.gavel_rounded, sancion.motivo),
            const SizedBox(height: 6),
            DatoFila(
              Icons.date_range_rounded,
              '${formatearFecha(sancion.fechaInicio)} — '
              '${formatearFecha(sancion.fechaFin)}',
            ),
          ],
        ),
      ),
    ),
  );
}

Color _colorEstado(EstadoSancion estado) => switch (estado) {
  EstadoSancion.activa => const Color(0xFFB45309),
  EstadoSancion.cumplida => const Color(0xFF1F9D55),
  _ => const Color(0xFF77798B),
};

String _titulo(Sancion sancion) =>
    sancion.id == null ? 'Sanción' : 'Sanción #${sancion.id}';

class _DetalleSancion extends StatefulWidget {
  const _DetalleSancion({
    required this.sancion,
    required this.api,
    required this.onActualizada,
  });

  final Sancion sancion;
  final SancionesApi api;

  final VoidCallback onActualizada;

  @override
  State<_DetalleSancion> createState() => _DetalleSancionState();
}

class _DetalleSancionState extends State<_DetalleSancion> {
  late Sancion _sancion = widget.sancion;

  bool _cargando = false;
  bool _actualizando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_sancion.id != null) _refrescar();
  }

  Future<void> _refrescar() async {
    final id = _sancion.id;
    if (id == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final detalle = await widget.api.consultar(id);
      if (!mounted) return;
      setState(() => _sancion = detalle);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarEstado(EstadoSancion nuevo) async {
    final id = _sancion.id;
    if (id == null) return;

    final cumple = nuevo == EstadoSancion.cumplida;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cumple ? 'Marcar como cumplida' : 'Anular la sanción'),
        content: Text(
          cumple
              ? 'La sanción #$id quedará en CUMPLIDA y dejará de bloquear la '
                    'emisión de planillas.'
              : 'La sanción #$id quedará en ANULADA y dejará de bloquear la '
                    'emisión de planillas. El registro no se borra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(cumple ? 'Marcar cumplida' : 'Anular'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() {
      _actualizando = true;
      _error = null;
    });
    try {
      final actualizada = await widget.api.actualizar(
        Sancion(
          id: _sancion.id,
          identificacionConductor: _sancion.identificacionConductor,
          motivo: _sancion.motivo,
          fechaInicio: _sancion.fechaInicio,
          fechaFin: _sancion.fechaFin,
          estado: nuevo,
        ),
      );
      if (!mounted) return;
      setState(() => _sancion = actualizada);
      widget.onActualizada();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sancion = _sancion;
    final activa = sancion.estado == EstadoSancion.activa;
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
                    _titulo(sancion),
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Etiqueta(
                  sancion.estado.apiValue,
                  color: _colorEstado(sancion.estado),
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
                habilitado: !_cargando && !_actualizando,
              ),
            ],
            const SizedBox(height: 16),
            CampoDetalle(
              Icons.badge_rounded,
              'Conductor',
              sancion.nombresConductor == null ||
                      sancion.nombresConductor!.isEmpty
                  ? sancion.identificacionConductor
                  : '${sancion.nombresConductor} · '
                        '${sancion.identificacionConductor}',
            ),
            CampoDetalle(Icons.gavel_rounded, 'Motivo', sancion.motivo),
            CampoDetalle(
              Icons.event_available_rounded,
              'Fecha de inicio',
              formatearFecha(sancion.fechaInicio),
            ),
            CampoDetalle(
              Icons.event_busy_rounded,
              'Fecha de fin',
              formatearFecha(sancion.fechaFin),
            ),
            CampoDetalle(
              Icons.history_rounded,
              'Fecha de registro',
              formatearFecha(sancion.fechaRegistro),
            ),
            const Divider(height: 24),
            if (activa) ...[
              const Text(
                'Mientras la sanción esté ACTIVA, el conductor no puede emitir '
                'planillas dentro del intervalo.',
                style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Marcar cumplida',
                icon: Icons.task_alt_rounded,
                isLoading: _actualizando,
                onPressed: _cargando || _actualizando
                    ? null
                    : () => _cambiarEstado(EstadoSancion.cumplida),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: _cargando || _actualizando
                      ? null
                      : () => _cambiarEstado(EstadoSancion.anulada),
                  child: const Text('Anular sanción'),
                ),
              ),
            ] else
              Text(
                sancion.estado == EstadoSancion.cumplida
                    ? 'La sanción ya fue cumplida; no bloquea planillas.'
                    : 'La sanción fue anulada; no bloquea planillas.',
                style: const TextStyle(color: Color(0xFF77798B)),
              ),
          ],
        ),
      ),
    );
  }
}
