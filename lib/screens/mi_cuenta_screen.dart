import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/common/page_query.dart';
import '../models/despacho/despacho.dart';
import '../models/planilla/planilla.dart';
import '../models/vehiculo/vehiculo.dart';
import '../services/remote/api_service.dart';
import '../services/remote/mi_cuenta_api.dart';
import '../utils/api_error_message.dart';
import '../utils/fechas.dart';
import '../utils/montos.dart';
import '../widgets/data_rows.dart';
import '../widgets/fields/custom_text_field.dart';

enum _Seccion { vehiculos, viajes, despachos }

class MiCuentaScreen extends StatefulWidget {
  const MiCuentaScreen({required this.api, super.key});

  final MiCuentaApi api;

  @override
  State<MiCuentaScreen> createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  static const int _pageSize = 20;

  final TextEditingController _placaController = TextEditingController();
  final TextEditingController _rutaController = TextEditingController();

  final List<Vehiculo> _vehiculos = <Vehiculo>[];
  final List<Planilla> _viajes = <Planilla>[];
  final List<Despacho> _despachos = <Despacho>[];

  _Seccion _seccion = _Seccion.vehiculos;

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
    _placaController.dispose();
    _rutaController.dispose();
    super.dispose();
  }

  Future<void> _consultar() => _cargar(reiniciar: true);

  Future<void> _cargarMas() async {
    _page += 1;
    await _cargar(reiniciar: false);
  }

  Future<void> _cambiarSeccion(_Seccion seccion) async {
    if (seccion == _seccion) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _seccion = seccion;
      _error = null;
      _hayMas = false;
    });
    await _consultar();
  }

  Future<void> _cargar({required bool reiniciar}) async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
      if (reiniciar) _page = 1;
    });

    final query = PageQuery(page: _page, pageSize: _pageSize);
    final placa = _placaController.text.trim();
    final ruta = _rutaController.text.trim();

    try {
      switch (_seccion) {
        case _Seccion.vehiculos:
          final resultado = await widget.api.vehiculos();
          if (!mounted) return;
          setState(() {
            _vehiculos
              ..clear()
              ..addAll(resultado);
            _hayMas = false;
          });
        case _Seccion.viajes:
          final resultado = await widget.api.viajes(
            query: query,
            desde: _desde,
            hasta: _hasta,
            placa: placa,
          );
          if (!mounted) return;
          setState(() {
            if (reiniciar) _viajes.clear();
            _viajes.addAll(resultado);
            _hayMas = query.hasNext(resultado.length);
          });
        case _Seccion.despachos:
          final resultado = await widget.api.despachos(
            query: query,
            desde: _desde,
            hasta: _hasta,
            placa: placa,
            ruta: ruta,
          );
          if (!mounted) return;
          setState(() {
            if (reiniciar) _despachos.clear();
            _despachos.addAll(resultado);
            _hayMas = query.hasNext(resultado.length);
          });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      final mensaje = mensajeDeApi(error);
      setState(() => _error = mensaje);
      if (_cantidad > 0) _mostrarMensaje(mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  int get _cantidad => switch (_seccion) {
    _Seccion.vehiculos => _vehiculos.length,
    _Seccion.viajes => _viajes.length,
    _Seccion.despachos => _despachos.length,
  };

  Future<void> _elegirFecha({required bool esDesde}) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    var inicial = (esDesde ? _desde : _hasta) ?? hoy;
    if (inicial.isAfter(hoy)) inicial = hoy;

    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2000),
      lastDate: hoy,
      helpText: esDesde ? 'Desde' : 'Hasta',
    );
    if (elegida == null || !mounted) return;
    setState(() {
      if (esDesde) {
        _desde = elegida;
        final hasta = _hasta;
        if (hasta != null && hasta.isBefore(elegida)) _hasta = elegida;
      } else {
        _hasta = elegida;
        final desde = _desde;
        if (desde != null && desde.isAfter(elegida)) _desde = elegida;
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
    _rutaController.clear();
    setState(() {
      _desde = null;
      _hasta = null;
    });
    _consultar();
  }

  Future<void> _abrirDetalle(int index) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => switch (_seccion) {
        _Seccion.vehiculos => _DetalleVehiculo(vehiculo: _vehiculos[index]),
        _Seccion.viajes => _DetalleViaje(planilla: _viajes[index]),
        _Seccion.despachos => _DetalleDespacho(despacho: _despachos[index]),
      },
    );
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mi cuenta'),
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
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _chip(_Seccion.vehiculos, 'Vehículos'),
            _chip(_Seccion.viajes, 'Viajes'),
            _chip(_Seccion.despachos, 'Despachos'),
          ],
        ),
        const SizedBox(height: 10),
        if (_seccion == _Seccion.vehiculos)
          const Text(
            'Estos son los vehículos afiliados a tu cuenta.',
            style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
          )
        else ...<Widget>[
          CustomTextField(
            controller: _placaController,
            label: 'Vehículo',
            hintText: 'Placa',
            onFieldSubmitted: (_) => _consultar(),
          ),
          if (_seccion == _Seccion.despachos) ...<Widget>[
            const SizedBox(height: 10),
            CustomTextField(
              controller: _rutaController,
              label: 'Ruta',
              hintText: 'Destino',
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => _consultar(),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _cargando ? null : () => _elegirFecha(esDesde: true),
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text(
                  _desde == null ? 'Desde' : 'Desde ${formatearFecha(_desde)}',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _cargando
                    ? null
                    : () => _elegirFecha(esDesde: false),
                icon: const Icon(Icons.event_available_rounded, size: 18),
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
      ],
    ),
  );

  Widget _chip(_Seccion seccion, String texto) => ChoiceChip(
    label: Text(texto),
    selected: _seccion == seccion,
    onSelected: _cargando ? null : (_) => _cambiarSeccion(seccion),
  );

  Widget _contenido() {
    if (_cargando && _cantidad == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_cantidad == 0) {
      return _error != null ? _vistaError() : _vistaVacia();
    }
    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _cantidad + (_hayMas ? 1 : 0),
        itemBuilder: (context, index) =>
            index >= _cantidad ? _botonCargarMas() : _elemento(index),
      ),
    );
  }

  Widget _elemento(int index) => switch (_seccion) {
    _Seccion.vehiculos => _tarjetaVehiculo(_vehiculos[index], index),
    _Seccion.viajes => _tarjetaViaje(_viajes[index], index),
    _Seccion.despachos => _tarjetaDespacho(_despachos[index], index),
  };

  Widget _vistaVacia() => switch (_seccion) {
    _Seccion.vehiculos => _mensaje(
      icon: Icons.directions_bus_outlined,
      titulo: 'Sin vehículos',
      detalle: 'No tienes vehículos afiliados a tu cuenta.',
      accion: TextButton(
        onPressed: _consultar,
        child: const Text('Reintentar'),
      ),
    ),
    _Seccion.viajes => _mensaje(
      icon: Icons.receipt_long_outlined,
      titulo: 'Sin viajes',
      detalle: 'No hay viajes para este rango de fechas.',
      accion: TextButton(
        onPressed: _limpiarFiltros,
        child: const Text('Limpiar filtros'),
      ),
    ),
    _Seccion.despachos => _mensaje(
      icon: Icons.route_outlined,
      titulo: 'Sin despachos',
      detalle: 'No hay despachos para estos filtros.',
      accion: TextButton(
        onPressed: _limpiarFiltros,
        child: const Text('Limpiar filtros'),
      ),
    ),
  };

  Widget _vistaError() => _mensaje(
    icon: Icons.cloud_off_rounded,
    titulo: 'No se pudo cargar Mi cuenta',
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

  static const Color _verde = Color(0xFF1F9D55);
  static const Color _gris = Color(0xFF77798B);

  Widget _tarjetaBase({
    required VoidCallback onTap,
    required String titulo,
    required Widget etiqueta,
    required List<Widget> datos,
    List<Widget> avisos = const <Widget>[],
  }) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                etiqueta,
              ],
            ),
            if (avisos.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: avisos),
            ],
            const SizedBox(height: 12),
            for (final dato in datos)
              Padding(padding: const EdgeInsets.only(bottom: 6), child: dato),
          ],
        ),
      ),
    ),
  );

  Widget _tarjetaVehiculo(Vehiculo vehiculo, int index) => _tarjetaBase(
    onTap: () => _abrirDetalle(index),
    titulo: vehiculo.placa,
    etiqueta: Etiqueta(vehiculo.tipo, color: AppTheme.secondary),
    avisos: <Widget>[
      if (vehiculo.soatVencido)
        const Etiqueta('SOAT VENCIDO', color: AppTheme.primary),
      if (!vehiculo.activo) const Etiqueta('INACTIVO', color: _gris),
    ],
    datos: <Widget>[
      DatoFila(
        Icons.directions_bus_rounded,
        '${vehiculo.marca} ${vehiculo.modelo} · '
        '${vehiculo.capacidadPasajeros} pasajeros',
      ),
      DatoFila(
        Icons.sell_rounded,
        vehiculo.tarifa == null
            ? 'Tarifa sin asignar'
            : 'Tarifa ${formatearMonto(vehiculo.tarifa!.total)}',
      ),
      DatoFila(
        Icons.verified_user_rounded,
        'SOAT ${formatearFecha(vehiculo.vigenciaSoat)} · '
        'TRM ${formatearFecha(vehiculo.vigenciaTrm)}',
      ),
    ],
  );

  Widget _tarjetaViaje(Planilla planilla, int index) => _tarjetaBase(
    onTap: () => _abrirDetalle(index),
    titulo: 'Planilla #${planilla.numero ?? '—'}',
    etiqueta: Etiqueta(
      planilla.estado.apiValue,
      color: planilla.estado == EstadoPlanilla.activa ? _verde : _gris,
    ),
    avisos: <Widget>[
      Etiqueta(
        planilla.estadoPago.apiValue,
        color: planilla.estaPagada ? _verde : AppTheme.primary,
      ),
    ],
    datos: <Widget>[
      DatoFila(
        Icons.event_available_rounded,
        '${formatearFecha(planilla.fecha)} · ${planilla.hora ?? '—'}',
      ),
      DatoFila(
        Icons.directions_bus_rounded,
        planilla.placaVehiculo ?? 'Sin placa',
      ),
      DatoFila(Icons.route_rounded, planilla.tipo ?? 'Sin tipo'),
      DatoFila(
        Icons.payments_rounded,
        'Pagado ${formatearMonto(planilla.valorPagado)}',
      ),
    ],
  );

  Widget _tarjetaDespacho(Despacho despacho, int index) => _tarjetaBase(
    onTap: () => _abrirDetalle(index),
    titulo: 'Despacho #${despacho.id ?? '—'}',
    etiqueta: Etiqueta(
      despacho.estado.apiValue,
      color: despacho.estaCancelado ? _gris : _verde,
    ),
    datos: <Widget>[
      DatoFila(Icons.route_rounded, despacho.ruta),
      DatoFila(
        Icons.event_available_rounded,
        '${formatearFecha(despacho.fecha)} · ${despacho.hora ?? '—'}',
      ),
      DatoFila(Icons.directions_bus_rounded, despacho.placaVehiculo),
      DatoFila(Icons.groups_rounded, '${despacho.numeroPasajeros} pasajeros'),
    ],
  );
}

class _DetalleVehiculo extends StatelessWidget {
  const _DetalleVehiculo({required this.vehiculo});

  final Vehiculo vehiculo;

  @override
  Widget build(BuildContext context) => SafeArea(
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
                  vehiculo.placa,
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Etiqueta(vehiculo.tipo, color: AppTheme.secondary),
            ],
          ),
          const SizedBox(height: 16),
          CampoDetalle(Icons.directions_bus_rounded, 'Marca', vehiculo.marca),
          CampoDetalle(
            Icons.confirmation_number_rounded,
            'Modelo',
            vehiculo.modelo,
          ),
          CampoDetalle(
            Icons.groups_rounded,
            'Capacidad',
            '${vehiculo.capacidadPasajeros} pasajeros',
          ),
          CampoDetalle(
            Icons.article_rounded,
            'Tarjeta de propiedad',
            vehiculo.tarjetaPropiedad,
          ),
          CampoDetalle(
            Icons.check_circle_rounded,
            'Estado',
            vehiculo.activo ? 'Activo' : 'Inactivo',
          ),
          CampoDetalle(
            Icons.shield_rounded,
            'Vigencia SOAT',
            formatearFecha(vehiculo.vigenciaSoat),
          ),
          CampoDetalle(
            Icons.verified_user_rounded,
            'Vigencia TRM',
            formatearFecha(vehiculo.vigenciaTrm),
          ),
          CampoDetalle(
            Icons.event_rounded,
            'Fecha de ingreso',
            formatearFecha(vehiculo.fechaIngreso),
          ),
          CampoDetalle(
            Icons.sell_rounded,
            'Tarifa',
            vehiculo.tarifa == null
                ? 'Sin tarifa asignada'
                : '${formatearMonto(vehiculo.tarifa!.total)} · '
                      'ID ${vehiculo.tarifa!.id}',
          ),
          if (vehiculo.soatVencido)
            const Text(
              'El SOAT está vencido: el vehículo se rechaza en planillas '
              'hasta renovarlo.',
              style: TextStyle(color: Color(0xFF8A1C1C), fontSize: 12),
            ),
        ],
      ),
    ),
  );
}

class _DetalleViaje extends StatelessWidget {
  const _DetalleViaje({required this.planilla});

  final Planilla planilla;

  @override
  Widget build(BuildContext context) {
    final conductor = planilla.conductor;
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
                    'Planilla #${planilla.numero ?? '—'}',
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Etiqueta(
                  planilla.estado.apiValue,
                  color: planilla.estado == EstadoPlanilla.activa
                      ? const Color(0xFF1F9D55)
                      : const Color(0xFF77798B),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CampoDetalle(
              Icons.event_available_rounded,
              'Fecha',
              formatearFecha(planilla.fecha),
            ),
            CampoDetalle(Icons.schedule_rounded, 'Hora', planilla.hora),
            CampoDetalle(
              Icons.directions_bus_rounded,
              'Vehículo',
              planilla.placaVehiculo,
            ),
            CampoDetalle(Icons.route_rounded, 'Tipo', planilla.tipo),
            CampoDetalle(
              Icons.payments_rounded,
              'Estado de pago',
              planilla.estadoPago.apiValue,
            ),
            CampoDetalle(
              Icons.attach_money_rounded,
              'Valor pagado',
              formatearMonto(planilla.valorPagado),
            ),
            CampoDetalle(
              Icons.sell_rounded,
              'Tarifa',
              planilla.tarifaId == null ? null : 'ID ${planilla.tarifaId}',
            ),
            CampoDetalle(
              Icons.badge_rounded,
              'Conductor',
              conductor == null
                  ? null
                  : conductor.nombre.isEmpty
                  ? conductor.identificacion
                  : '${conductor.nombre} · ${conductor.identificacion}',
            ),
          ],
        ),
      ),
    );
  }
}

class _DetalleDespacho extends StatelessWidget {
  const _DetalleDespacho({required this.despacho});

  final Despacho despacho;

  @override
  Widget build(BuildContext context) => SafeArea(
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
                  'Despacho #${despacho.id ?? '—'}',
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
          if (despacho.estaCancelado) ...<Widget>[
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
          ],
        ],
      ),
    ),
  );
}
