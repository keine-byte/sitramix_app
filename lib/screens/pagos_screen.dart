import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/common/page_query.dart';
import '../models/pago/pago.dart';
import '../services/remote/api_service.dart';
import '../services/remote/pagos_api.dart';
import '../utils/api_error_message.dart';
import '../utils/fechas.dart';
import '../utils/montos.dart';
import '../widgets/data_rows.dart';
import '../widgets/fields/custom_text_field.dart';

class PagosScreen extends StatefulWidget {
  const PagosScreen({required this.api, super.key});

  final PagosApi api;

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  static const int _pageSize = 20;

  final TextEditingController _planillaController = TextEditingController();
  final TextEditingController _placaController = TextEditingController();

  final List<Pago> _pagos = <Pago>[];

  DateTime? _desde;
  DateTime? _hasta;

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
    _planillaController.dispose();
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
        numeroPlanilla: int.tryParse(_planillaController.text.trim()),
        placa: _placaController.text.trim(),
        desde: _desde,
        hasta: _hasta,
      );
      if (!mounted) return;
      setState(() {
        if (reiniciar) _pagos.clear();
        _pagos.addAll(resultado);
        _hayMas = query.hasNext(resultado.length);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      final mensaje = mensajeDeApi(error);
      setState(() => _error = mensaje);
      if (_pagos.isNotEmpty) _mostrarMensaje(mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirFecha({required bool esDesde}) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final preferida = esDesde ? _desde : _hasta;
    var inicial = preferida ?? _desde ?? hoy;
    if (inicial.isAfter(hoy)) inicial = hoy;

    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2000),
      lastDate: hoy,
      helpText: esDesde ? 'Pagos desde' : 'Pagos hasta',
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
    _planillaController.clear();
    _placaController.clear();
    setState(() {
      _desde = null;
      _hasta = null;
    });
    _consultar();
  }

  Future<void> _abrirDetalle(Pago pago) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetallePago(pago: pago, api: widget.api),
    );
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pagos'),
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
        CustomTextField(
          controller: _planillaController,
          label: 'Planilla',
          hintText: 'Número',
          keyboardType: TextInputType.number,
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
              onPressed: _cargando ? null : () => _elegirFecha(esDesde: true),
              icon: const Icon(Icons.event_available_rounded, size: 18),
              label: Text(
                _desde == null ? 'Desde' : 'Desde ${formatearFecha(_desde)}',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _cargando ? null : () => _elegirFecha(esDesde: false),
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
    if (_cargando && _pagos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pagos.isEmpty) {
      return _error != null ? _vistaError() : _vistaVacia();
    }
    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _pagos.length + (_hayMas ? 1 : 0),
        itemBuilder: (context, index) => index >= _pagos.length
            ? _botonCargarMas()
            : _tarjeta(_pagos[index]),
      ),
    );
  }

  Widget _vistaVacia() => _mensaje(
    icon: Icons.receipt_long_rounded,
    titulo: 'Sin pagos',
    detalle: 'No hay pagos para estos filtros.',
    accion: TextButton(
      onPressed: _limpiarFiltros,
      child: const Text('Limpiar filtros'),
    ),
  );

  Widget _vistaError() => _mensaje(
    icon: Icons.cloud_off_rounded,
    titulo: 'No se pudieron cargar los pagos',
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

  Widget _tarjeta(Pago pago) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
    child: InkWell(
      onTap: () => _abrirDetalle(pago),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _titulo(pago),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatearMonto(pago.valorPagado),
                  style: const TextStyle(
                    color: Color(0xFF1F9D55),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DatoFila(
              Icons.receipt_long_rounded,
              'Planilla ${pago.numeroPlanilla}',
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.event_available_rounded,
              'Fecha de pago '
              '${formatearFecha(pago.fechaPago, vacio: 'sin registrar')}',
            ),
            if (pago.registradoPor != null &&
                pago.registradoPor!.isNotEmpty) ...[
              const SizedBox(height: 6),
              DatoFila(Icons.badge_rounded, 'Registró ${pago.registradoPor}'),
            ],
          ],
        ),
      ),
    ),
  );
}

String _titulo(Pago pago) => pago.id == null ? 'Pago' : 'Pago #${pago.id}';

class _DetallePago extends StatefulWidget {
  const _DetallePago({required this.pago, required this.api});

  final Pago pago;
  final PagosApi api;

  @override
  State<_DetallePago> createState() => _DetallePagoState();
}

class _DetallePagoState extends State<_DetallePago> {
  late Pago _pago = widget.pago;

  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_pago.id != null) _refrescar();
  }

  Future<void> _refrescar() async {
    final id = _pago.id;
    if (id == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final detalle = await widget.api.consultar(id);
      if (!mounted) return;
      setState(() => _pago = detalle);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titulo(_pago),
            style: const TextStyle(
              color: AppTheme.secondary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_cargando) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            AvisoAccion(_error!, onAccion: _refrescar, habilitado: !_cargando),
          ],
          const SizedBox(height: 16),
          CampoDetalle(
            Icons.receipt_long_rounded,
            'Planilla',
            '${_pago.numeroPlanilla}',
          ),
          CampoDetalle(
            Icons.payments_rounded,
            'Valor pagado',
            formatearMonto(_pago.valorPagado),
          ),
          CampoDetalle(
            Icons.event_available_rounded,
            'Fecha de pago',
            formatearFecha(_pago.fechaPago),
          ),
          CampoDetalle(
            Icons.badge_rounded,
            'Registrado por',
            _pago.registradoPor,
          ),
          CampoDetalle(
            Icons.history_rounded,
            'Fecha de registro',
            formatearFecha(_pago.fechaRegistro),
          ),
          const SizedBox(height: 4),
          const Text(
            'El valor lo define la tarifa asociada a la planilla; el pago no '
            'modifica el estado operativo de la planilla.',
            style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
