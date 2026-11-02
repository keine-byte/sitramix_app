import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/common/page_query.dart';
import '../models/tarifa/tarifa.dart';
import '../services/remote/api_service.dart';
import '../services/remote/tarifas_api.dart';
import '../utils/api_error_message.dart';
import '../utils/montos.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/data_rows.dart';
import 'formulario_tarifa_screen.dart';

class TarifasScreen extends StatefulWidget {
  const TarifasScreen({required this.api, super.key});

  final TarifasApi api;

  @override
  State<TarifasScreen> createState() => _TarifasScreenState();
}

class _TarifasScreenState extends State<TarifasScreen> {
  static const int _pageSize = 20;

  final List<Tarifa> _tarifas = <Tarifa>[];

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
      final resultado = await widget.api.listar(query: query, activo: _activo);
      if (!mounted) return;
      setState(() {
        if (reiniciar) _tarifas.clear();
        _tarifas.addAll(resultado);
        _hayMas = query.hasNext(resultado.length);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      final mensaje = mensajeDeApi(error);
      setState(() => _error = mensaje);
      if (_tarifas.isNotEmpty) _mostrarMensaje(mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarFiltro(bool? activo) {
    if (_activo == activo) return;
    setState(() => _activo = activo);
    _consultar();
  }

  Future<void> _abrirDetalle(Tarifa tarifa) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleTarifa(
        tarifa: tarifa,
        api: widget.api,
        onInactivada: _consultar,
      ),
    );
  }

  Future<void> _abrirFormulario() async {
    final guardada = await Navigator.of(context).push<Tarifa>(
      MaterialPageRoute<Tarifa>(
        builder: (_) => FormularioTarifaScreen(api: widget.api),
      ),
    );
    if (guardada == null || !mounted) return;
    _mostrarMensaje(
      guardada.id == null
          ? 'Tarifa registrada.'
          : 'Tarifa #${guardada.id} registrada.',
    );
    await _consultar();
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tarifas'),
      titleTextStyle: const TextStyle(
        color: AppTheme.secondary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      actions: [
        IconButton(
          tooltip: 'Nueva tarifa',
          onPressed: _abrirFormulario,
          icon: const Icon(Icons.add_rounded),
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
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Todas'),
          selected: _activo == null,
          onSelected: (_) => _cambiarFiltro(null),
        ),
        ChoiceChip(
          label: const Text('Activas'),
          selected: _activo == true,
          onSelected: (_) => _cambiarFiltro(true),
        ),
        ChoiceChip(
          label: const Text('Inactivas'),
          selected: _activo == false,
          onSelected: (_) => _cambiarFiltro(false),
        ),
      ],
    ),
  );

  Widget _contenido() {
    if (_cargando && _tarifas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tarifas.isEmpty) {
      return _error != null ? _vistaError() : _vistaVacia();
    }
    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _tarifas.length + (_hayMas ? 1 : 0),
        itemBuilder: (context, index) => index >= _tarifas.length
            ? _botonCargarMas()
            : _tarjeta(_tarifas[index]),
      ),
    );
  }

  Widget _vistaVacia() => _mensaje(
    icon: Icons.sell_outlined,
    titulo: 'Sin tarifas',
    detalle: 'No hay tarifas para este filtro.',
    accion: TextButton(
      onPressed: () => _cambiarFiltro(null),
      child: const Text('Ver todas'),
    ),
  );

  Widget _vistaError() => _mensaje(
    icon: Icons.cloud_off_rounded,
    titulo: 'No se pudieron cargar las tarifas',
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

  Widget _tarjeta(Tarifa tarifa) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
    child: InkWell(
      onTap: () => _abrirDetalle(tarifa),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _titulo(tarifa),
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
                  tarifa.activo ? 'ACTIVA' : 'INACTIVA',
                  color: tarifa.activo
                      ? const Color(0xFF1F9D55)
                      : const Color(0xFF77798B),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DatoFila(
              Icons.summarize_rounded,
              'Total ${formatearMonto(tarifa.total)}',
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.payments_rounded,
              'Aportes y gastos varios '
              '${formatearMonto(tarifa.aportesGastosVarios)}',
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.savings_rounded,
              'Fondo de reposición ${formatearMonto(tarifa.fondoReposicion)}',
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.groups_rounded,
              'Aporte social socio ${formatearMonto(tarifa.aporteSocialSocio)}',
            ),
          ],
        ),
      ),
    ),
  );
}

String _titulo(Tarifa tarifa) =>
    tarifa.id == null ? 'Tarifa' : 'Tarifa #${tarifa.id}';

class _DetalleTarifa extends StatefulWidget {
  const _DetalleTarifa({
    required this.tarifa,
    required this.api,
    required this.onInactivada,
  });

  final Tarifa tarifa;
  final TarifasApi api;

  final VoidCallback onInactivada;

  @override
  State<_DetalleTarifa> createState() => _DetalleTarifaState();
}

class _DetalleTarifaState extends State<_DetalleTarifa> {
  late Tarifa _tarifa = widget.tarifa;

  bool _cargando = false;
  bool _inactivando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_tarifa.id != null) _refrescar();
  }

  Future<void> _refrescar() async {
    final id = _tarifa.id;
    if (id == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final detalle = await widget.api.consultar(id);
      if (!mounted) return;
      setState(() => _tarifa = detalle);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _inactivar() async {
    final id = _tarifa.id;
    if (id == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inactivar tarifa'),
        content: Text(
          'La tarifa #$id quedará inactiva y no se podrá asignar a nuevas '
          'planillas. No se borra: sus planillas históricas conservan el '
          'valor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Inactivar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() {
      _inactivando = true;
      _error = null;
    });
    try {
      final resultado = await widget.api.inactivar(id);
      if (!mounted) return;
      setState(() => _tarifa = resultado);
      widget.onInactivada();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _inactivando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tarifa = _tarifa;
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
                    _titulo(tarifa),
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Etiqueta(
                  tarifa.activo ? 'ACTIVA' : 'INACTIVA',
                  color: tarifa.activo
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
                habilitado: !_cargando && !_inactivando,
              ),
            ],
            const SizedBox(height: 16),
            CampoDetalle(
              Icons.payments_rounded,
              'Aportes y gastos varios',
              formatearMonto(tarifa.aportesGastosVarios),
            ),
            CampoDetalle(
              Icons.savings_rounded,
              'Fondo de reposición',
              formatearMonto(tarifa.fondoReposicion),
            ),
            CampoDetalle(
              Icons.groups_rounded,
              'Aporte social socio',
              formatearMonto(tarifa.aporteSocialSocio),
            ),
            CampoDetalle(
              Icons.summarize_rounded,
              'Total',
              formatearMonto(tarifa.total),
            ),
            const SizedBox(height: 4),
            const Text(
              'El total lo calcula el backend con los tres conceptos y es el '
              'valor que se copia a los pagos de planilla.',
              style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (tarifa.activo)
              PrimaryButton(
                label: 'Inactivar tarifa',
                icon: Icons.block_rounded,
                isLoading: _inactivando,
                onPressed: _cargando || _inactivando ? null : _inactivar,
              )
            else
              const Text(
                'La tarifa ya está inactiva.',
                style: TextStyle(color: Color(0xFF77798B)),
              ),
          ],
        ),
      ),
    );
  }
}
