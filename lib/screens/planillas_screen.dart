import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/common/page_query.dart';
import '../models/planilla/planilla.dart';
import '../services/remote/api_service.dart';
import '../services/remote/planillas_api.dart';
import '../utils/api_error_message.dart';
import '../utils/fechas.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/data_rows.dart';
import '../widgets/fields/custom_text_field.dart';
import 'formulario_planilla_screen.dart';
import 'planilla_masiva_screen.dart';

class PlanillasScreen extends StatefulWidget {
  const PlanillasScreen({
    required this.api,
    this.puedeAnular = true,
    super.key,
  });

  final PlanillasApi api;

  final bool puedeAnular;

  @override
  State<PlanillasScreen> createState() => _PlanillasScreenState();
}

class _PlanillasScreenState extends State<PlanillasScreen> {
  static const int _pageSize = 20;

  final TextEditingController _placaController = TextEditingController();

  final List<Planilla> _planillas = <Planilla>[];

  EstadoPlanilla? _estado;
  DateTime? _fecha;
  int _page = 1;
  bool _hayMas = false;
  bool _cargando = false;
  String? _error;

  int? _anulando;

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
        fecha: _fecha,
        vehiculo: _placaController.text.trim().toUpperCase(),
        estado: _estado,
      );
      if (!mounted) return;
      setState(() {
        if (reiniciar) _planillas.clear();
        _planillas.addAll(resultado);
        _hayMas = query.hasNext(resultado.length);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      final mensaje = mensajeDeApi(error);
      setState(() => _error = mensaje);
      if (_planillas.isNotEmpty) _mostrarMensaje(mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarEstado(EstadoPlanilla? estado) {
    if (_estado == estado) return;
    setState(() => _estado = estado);
    _consultar();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? ahora,
      firstDate: DateTime(ahora.year - 5),
      lastDate: ahora,
      helpText: 'Fecha de la planilla',
    );
    if (elegida == null || !mounted) return;
    setState(() => _fecha = elegida);
    _consultar();
  }

  void _limpiarFiltros() {
    _placaController.clear();
    setState(() {
      _estado = null;
      _fecha = null;
    });
    _consultar();
  }

  Future<void> _anular(Planilla planilla) async {
    final numero = planilla.numero;
    if (numero == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Anular planilla $numero'),
        content: const Text(
          'La planilla quedará ANULADA. Se conservan los pagos y el historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _anulando = numero);
    try {
      final anulada = await widget.api.anular(numero);
      if (!mounted) return;
      setState(() {
        final index = _planillas.indexWhere((item) => item.numero == numero);
        if (index >= 0) _planillas[index] = anulada;
      });
      _mostrarMensaje('Planilla $numero anulada.');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      _mostrarMensaje(mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _anulando = null);
    }
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _abrirMasiva() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlanillaMasivaScreen(api: widget.api),
      ),
    );
    if (!mounted) return;
    await _consultar();
  }

  Future<void> _abrirFormulario() async {
    final guardada = await Navigator.of(context).push<Planilla>(
      MaterialPageRoute<Planilla>(
        builder: (_) => FormularioPlanillaScreen(api: widget.api),
      ),
    );
    if (guardada == null || !mounted) return;
    _mostrarMensaje(
      guardada.numero == null
          ? 'Planilla registrada.'
          : 'Planilla ${guardada.numero} registrada.',
    );
    await _consultar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Planillas'),
      titleTextStyle: const TextStyle(
        color: AppTheme.secondary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      actions: [
        IconButton(
          tooltip: 'Nueva planilla',
          onPressed: _abrirFormulario,
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          tooltip: 'Planilla masiva',
          onPressed: _abrirMasiva,
          icon: const Icon(Icons.playlist_add_rounded),
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
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _placaController,
                label: 'Placa',
                hintText: 'Ej. BRU001',
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _consultar(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _elegirFecha,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(_fecha == null ? 'Fecha' : formatearFecha(_fecha)),
            ),
          ],
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
              selected: _estado == EstadoPlanilla.activa,
              onSelected: (_) => _cambiarEstado(EstadoPlanilla.activa),
            ),
            ChoiceChip(
              label: const Text('Anuladas'),
              selected: _estado == EstadoPlanilla.anulada,
              onSelected: (_) => _cambiarEstado(EstadoPlanilla.anulada),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _contenido() {
    if (_cargando && _planillas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_planillas.isEmpty) {
      return _error != null ? _vistaError() : _vistaVacia();
    }
    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _planillas.length + (_hayMas ? 1 : 0),
        itemBuilder: (context, index) => index >= _planillas.length
            ? _botonCargarMas()
            : _tarjeta(_planillas[index]),
      ),
    );
  }

  Widget _vistaVacia() => _mensaje(
    icon: Icons.receipt_long_outlined,
    titulo: 'Sin planillas',
    detalle: 'No hay planillas para estos filtros.',
    accion: TextButton(
      onPressed: _limpiarFiltros,
      child: const Text('Limpiar filtros'),
    ),
  );

  Widget _vistaError() => _mensaje(
    icon: Icons.cloud_off_rounded,
    titulo: 'No se pudieron cargar las planillas',
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

  Widget _tarjeta(Planilla planilla) {
    final conductor = planilla.conductor;
    final anulada = planilla.estado == EstadoPlanilla.anulada;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Planilla ${planilla.numero ?? '—'}',
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
                  planilla.estado.apiValue,
                  color: anulada ? AppTheme.primary : AppTheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            DatoFila(
              Icons.event_rounded,
              '${formatearFecha(planilla.fecha, vacio: 'Sin fecha')} · '
              '${_formatearHora(planilla.hora)}',
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.directions_car_rounded,
              '${planilla.placaVehiculo ?? 'Sin placa'} · '
              '${planilla.tipo ?? 'Sin tipo'}',
            ),
            if (conductor != null) ...[
              const SizedBox(height: 6),
              DatoFila(
                Icons.person_rounded,
                '${conductor.nombre} (${conductor.identificacion})',
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Etiqueta(
                      planilla.estadoPago.apiValue,
                      color: planilla.estaPagada
                          ? const Color(0xFF1F9D55)
                          : const Color(0xFFB26A00),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatearValor(planilla.valorPagado),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (widget.puedeAnular && !anulada)
                  TextButton.icon(
                    onPressed: _anulando == null
                        ? () => _anular(planilla)
                        : null,
                    icon: _anulando == planilla.numero
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.block_rounded, size: 18),
                    label: const Text('Anular'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatearHora(String? hora) {
    if (hora == null || hora.isEmpty) return '--:--';
    return hora.length >= 5 ? hora.substring(0, 5) : hora;
  }

  String _formatearValor(double valor) {
    final digitos = valor.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      final restantes = digitos.length - i;
      buffer.write(digitos[i]);
      if (restantes > 1 && restantes % 3 == 1) buffer.write('.');
    }
    return '\$ ${buffer.toString()}';
  }
}
