import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/common/page_query.dart';
import '../models/conductor/conductor.dart';
import '../services/remote/api_service.dart';
import '../services/remote/conductores_api.dart';
import '../utils/api_error_message.dart';
import '../utils/fechas.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/data_rows.dart';
import '../widgets/fields/custom_text_field.dart';
import 'formulario_conductor_screen.dart';

class ConductoresScreen extends StatefulWidget {
  const ConductoresScreen({required this.api, super.key});

  final ConductoresApi api;

  @override
  State<ConductoresScreen> createState() => _ConductoresScreenState();
}

class _ConductoresScreenState extends State<ConductoresScreen> {
  static const int _pageSize = 20;

  final TextEditingController _nombresController = TextEditingController();

  final List<Conductor> _conductores = <Conductor>[];

  bool? _activo;
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
    _nombresController.dispose();
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
        nombres: _nombresController.text.trim(),
        activo: _activo,
      );
      if (!mounted) return;
      setState(() {
        if (reiniciar) _conductores.clear();
        _conductores.addAll(resultado);
        _hayMas = query.hasNext(resultado.length);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      final mensaje = mensajeDeApi(error);
      setState(() => _error = mensaje);
      if (_conductores.isNotEmpty) _mostrarMensaje(mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarActivo(bool? activo) {
    if (_activo == activo) return;
    setState(() => _activo = activo);
    _consultar();
  }

  void _limpiarFiltros() {
    _nombresController.clear();
    setState(() => _activo = null);
    _consultar();
  }

  Future<void> _abrirDetalle(Conductor conductor) async {
    FocusScope.of(context).unfocus();
    final aEditar = await showModalBottomSheet<Conductor>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleConductor(conductor: conductor, api: widget.api),
    );
    if (aEditar == null || !mounted) return;
    await _abrirFormulario(conductor: aEditar);
  }

  Future<void> _abrirFormulario({Conductor? conductor}) async {
    final guardado = await Navigator.of(context).push<Conductor>(
      MaterialPageRoute<Conductor>(
        builder: (_) =>
            FormularioConductorScreen(api: widget.api, conductor: conductor),
      ),
    );
    if (guardado == null || !mounted) return;
    _mostrarMensaje(
      conductor == null
          ? 'Conductor ${guardado.identificacion} registrado.'
          : 'Conductor ${guardado.identificacion} actualizado.',
    );
    await _consultar();
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Conductores'),
      titleTextStyle: const TextStyle(
        color: AppTheme.secondary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      actions: [
        IconButton(
          tooltip: 'Nuevo conductor',
          onPressed: _abrirFormulario,
          icon: const Icon(Icons.badge_rounded),
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
          controller: _nombresController,
          label: 'Nombres',
          hintText: 'Ej. Ana Perez',
          textInputAction: TextInputAction.search,
          onFieldSubmitted: (_) => _consultar(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: _activo == null,
              onSelected: (_) => _cambiarActivo(null),
            ),
            ChoiceChip(
              label: const Text('Activos'),
              selected: _activo == true,
              onSelected: (_) => _cambiarActivo(true),
            ),
            ChoiceChip(
              label: const Text('Inactivos'),
              selected: _activo == false,
              onSelected: (_) => _cambiarActivo(false),
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
    if (_cargando && _conductores.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_conductores.isEmpty) {
      return _error != null ? _vistaError() : _vistaVacia();
    }
    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _conductores.length + (_hayMas ? 1 : 0),
        itemBuilder: (context, index) => index >= _conductores.length
            ? _botonCargarMas()
            : _tarjeta(_conductores[index]),
      ),
    );
  }

  Widget _vistaVacia() => _mensaje(
    icon: Icons.badge_outlined,
    titulo: 'Sin conductores',
    detalle: 'No hay conductores para estos filtros.',
    accion: TextButton(
      onPressed: _limpiarFiltros,
      child: const Text('Limpiar filtros'),
    ),
  );

  Widget _vistaError() => _mensaje(
    icon: Icons.cloud_off_rounded,
    titulo: 'No se pudieron cargar los conductores',
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

  Widget _tarjeta(Conductor conductor) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
    child: InkWell(
      onTap: () => _abrirDetalle(conductor),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    conductor.nombres.isEmpty
                        ? 'Sin nombre'
                        : conductor.nombres,
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
                  conductor.activo ? 'ACTIVO' : 'INACTIVO',
                  color: conductor.activo
                      ? const Color(0xFF1F9D55)
                      : const Color(0xFFB26A00),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DatoFila(Icons.badge_rounded, conductor.identificacion),
            const SizedBox(height: 6),
            DatoFila(
              Icons.credit_card_rounded,
              'Licencia ${conductor.categoriaLicencia ?? '—'} · '
              '${conductor.numeroLicencia ?? 'Sin número'}',
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: DatoFila(
                    Icons.event_busy_rounded,
                    'Vigencia '
                    '${formatearFecha(conductor.vigenciaLicencia, vacio: 'sin registrar')}',
                  ),
                ),
                if (conductor.licenciaVencida) ...[
                  const SizedBox(width: 8),
                  const Etiqueta('VENCIDA', color: AppTheme.primary),
                ],
              ],
            ),
            if (conductor.celular != null) ...[
              const SizedBox(height: 6),
              DatoFila(Icons.phone_rounded, conductor.celular!),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DetalleConductor extends StatefulWidget {
  const _DetalleConductor({required this.conductor, required this.api});

  final Conductor conductor;
  final ConductoresApi api;

  @override
  State<_DetalleConductor> createState() => _DetalleConductorState();
}

class _DetalleConductorState extends State<_DetalleConductor> {
  late Conductor _conductor = widget.conductor;

  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refrescar();
  }

  Future<void> _refrescar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final detalle = await widget.api.consultar(
        widget.conductor.identificacion,
      );
      if (!mounted) return;
      setState(() => _conductor = detalle);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conductor = _conductor;
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
                    conductor.nombres.isEmpty
                        ? 'Sin nombre'
                        : conductor.nombres,
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Etiqueta(
                  conductor.activo ? 'ACTIVO' : 'INACTIVO',
                  color: conductor.activo
                      ? const Color(0xFF1F9D55)
                      : const Color(0xFFB26A00),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Identificación ${conductor.identificacion}',
              style: const TextStyle(color: Color(0xFF77798B)),
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
                habilitado: !_cargando,
              ),
            ],
            const SizedBox(height: 16),
            CampoDetalle(
              Icons.credit_card_rounded,
              'Número de licencia',
              conductor.numeroLicencia,
            ),
            CampoDetalle(
              Icons.category_rounded,
              'Categoría',
              conductor.categoriaLicencia,
            ),
            CampoDetalle(
              Icons.event_rounded,
              'Vigencia de la licencia',
              formatearFecha(conductor.vigenciaLicencia),
            ),
            if (conductor.licenciaVencida) ...[
              const SizedBox(height: 4),
              AvisoAccion(
                'La licencia está vencida: el vehículo se rechaza en '
                'planillas masivas.',
                onAccion: _refrescar,
                etiquetaAccion: 'Volver a consultar',
                habilitado: !_cargando,
              ),
            ],
            const SizedBox(height: 12),
            CampoDetalle(
              Icons.cake_rounded,
              'Fecha de nacimiento',
              formatearFecha(conductor.fechaNacimiento),
            ),
            CampoDetalle(Icons.phone_rounded, 'Celular', conductor.celular),
            CampoDetalle(Icons.mail_rounded, 'Correo', conductor.correo),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _cargando
                  ? null
                  : () => Navigator.of(context).pop<Conductor>(_conductor),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Editar conductor'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
