import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/common/page_query.dart';
import '../models/vehiculo/vehiculo.dart';
import '../services/remote/api_service.dart';
import '../services/remote/vehiculos_api.dart';
import '../utils/api_error_message.dart';
import '../utils/fechas.dart';
import '../utils/montos.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/data_rows.dart';
import '../widgets/fields/custom_text_field.dart';
import 'formulario_vehiculo_screen.dart';

class VehiculosScreen extends StatefulWidget {
  const VehiculosScreen({required this.api, super.key});

  final VehiculosApi api;

  @override
  State<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends State<VehiculosScreen> {
  static const int _pageSize = 20;

  final TextEditingController _placaController = TextEditingController();

  final List<Vehiculo> _vehiculos = <Vehiculo>[];

  final Set<String> _tipos = <String>{};

  String? _tipo;
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
        tipo: _tipo,
      );
      if (!mounted) return;
      setState(() {
        if (reiniciar) _vehiculos.clear();
        _vehiculos.addAll(resultado);
        _hayMas = query.hasNext(resultado.length);
        _tipos.addAll(resultado.map((v) => v.tipo).where((t) => t.isNotEmpty));
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      final mensaje = mensajeDeApi(error);
      setState(() => _error = mensaje);
      if (_vehiculos.isNotEmpty) _mostrarMensaje(mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarTipo(String? tipo) {
    if (_tipo == tipo) return;
    setState(() => _tipo = tipo);
    _consultar();
  }

  void _limpiarFiltros() {
    _placaController.clear();
    setState(() => _tipo = null);
    _consultar();
  }

  Future<void> _abrirDetalle(Vehiculo vehiculo) async {
    FocusScope.of(context).unfocus();
    final aEditar = await showModalBottomSheet<Vehiculo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleVehiculo(vehiculo: vehiculo, api: widget.api),
    );
    if (aEditar == null || !mounted) return;
    await _abrirFormulario(vehiculo: aEditar);
  }

  Future<void> _abrirFormulario({Vehiculo? vehiculo}) async {
    final guardado = await Navigator.of(context).push<Vehiculo>(
      MaterialPageRoute<Vehiculo>(
        builder: (_) =>
            FormularioVehiculoScreen(api: widget.api, vehiculo: vehiculo),
      ),
    );
    if (guardado == null || !mounted) return;
    _mostrarMensaje(
      vehiculo == null
          ? 'Vehículo ${guardado.placa} registrado.'
          : 'Vehículo ${guardado.placa} actualizado.',
    );
    await _consultar();
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Vehículos'),
      titleTextStyle: const TextStyle(
        color: AppTheme.secondary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      actions: [
        IconButton(
          tooltip: 'Nuevo vehículo',
          onPressed: _abrirFormulario,
          icon: const Icon(Icons.directions_car_filled_rounded),
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

  Widget _filtros() {
    final tipos = _tipos.toList()..sort();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            controller: _placaController,
            label: 'Placa',
            hintText: 'Ej. BRU001',
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (_) => _consultar(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (tipos.isNotEmpty)
                DropdownButton<String?>(
                  value: _tipo,
                  onChanged: _cargando ? null : _cambiarTipo,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos los tipos'),
                    ),
                    ...tipos.map(
                      (tipo) => DropdownMenuItem<String?>(
                        value: tipo,
                        child: Text(tipo),
                      ),
                    ),
                  ],
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
  }

  Widget _contenido() {
    if (_cargando && _vehiculos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_vehiculos.isEmpty) {
      return _error != null ? _vistaError() : _vistaVacia();
    }
    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _vehiculos.length + (_hayMas ? 1 : 0),
        itemBuilder: (context, index) => index >= _vehiculos.length
            ? _botonCargarMas()
            : _tarjeta(_vehiculos[index]),
      ),
    );
  }

  Widget _vistaVacia() => _mensaje(
    icon: Icons.directions_bus_outlined,
    titulo: 'Sin vehículos',
    detalle: 'No hay vehículos para estos filtros.',
    accion: TextButton(
      onPressed: _limpiarFiltros,
      child: const Text('Limpiar filtros'),
    ),
  );

  Widget _vistaError() => _mensaje(
    icon: Icons.cloud_off_rounded,
    titulo: 'No se pudieron cargar los vehículos',
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

  Widget _tarjeta(Vehiculo vehiculo) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
    child: InkWell(
      onTap: () => _abrirDetalle(vehiculo),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehiculo.placa.isEmpty ? 'Sin placa' : vehiculo.placa,
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
                  vehiculo.activo ? 'ACTIVO' : 'INACTIVO',
                  color: vehiculo.activo
                      ? const Color(0xFF1F9D55)
                      : const Color(0xFFB26A00),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DatoFila(Icons.directions_bus_rounded, _describir(vehiculo)),
            const SizedBox(height: 6),
            DatoFila(
              Icons.airline_seat_recline_normal_rounded,
              '${vehiculo.capacidadPasajeros} puestos',
            ),
            const SizedBox(height: 6),
            DatoFila(
              Icons.payments_rounded,
              'Tarifa '
              '${formatearMonto(vehiculo.tarifa?.total, vacio: 'sin asignar')}',
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: DatoFila(
                    Icons.verified_rounded,
                    'SOAT ${formatearFecha(vehiculo.vigenciaSoat, vacio: 'sin registrar')}',
                  ),
                ),
                if (vehiculo.soatVencido) ...[
                  const SizedBox(width: 8),
                  const Etiqueta('SOAT VENCIDO', color: AppTheme.primary),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetalleVehiculo extends StatefulWidget {
  const _DetalleVehiculo({required this.vehiculo, required this.api});

  final Vehiculo vehiculo;
  final VehiculosApi api;

  @override
  State<_DetalleVehiculo> createState() => _DetalleVehiculoState();
}

class _DetalleVehiculoState extends State<_DetalleVehiculo> {
  late Vehiculo _vehiculo = widget.vehiculo;

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
      final detalle = await widget.api.consultar(widget.vehiculo.placa);
      if (!mounted) return;
      setState(() => _vehiculo = detalle);
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
    final vehiculo = _vehiculo;
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
                    vehiculo.placa.isEmpty ? 'Sin placa' : vehiculo.placa,
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Etiqueta(
                  vehiculo.activo ? 'ACTIVO' : 'INACTIVO',
                  color: vehiculo.activo
                      ? const Color(0xFF1F9D55)
                      : const Color(0xFFB26A00),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _describir(vehiculo),
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
              Icons.airline_seat_recline_normal_rounded,
              'Capacidad de pasajeros',
              '${vehiculo.capacidadPasajeros}',
            ),
            CampoDetalle(
              Icons.description_rounded,
              'Tarjeta de propiedad',
              vehiculo.tarjetaPropiedad,
            ),
            CampoDetalle(
              Icons.payments_rounded,
              'Tarifa asignada',
              vehiculo.tarifa == null
                  ? 'Sin asignar'
                  : '${formatearMonto(vehiculo.tarifa!.total)} '
                        '(tarifa ${vehiculo.tarifa!.id})',
            ),
            CampoDetalle(
              Icons.verified_rounded,
              'Vigencia del SOAT',
              formatearFecha(vehiculo.vigenciaSoat),
            ),
            CampoDetalle(
              Icons.fact_check_rounded,
              'Vigencia del TRM',
              formatearFecha(vehiculo.vigenciaTrm),
            ),
            if (vehiculo.soatVencido) ...[
              const SizedBox(height: 4),
              AvisoAccion(
                'El SOAT está vencido: el vehículo se rechaza en planillas '
                'masivas.',
                onAccion: _refrescar,
                etiquetaAccion: 'Volver a consultar',
                habilitado: !_cargando,
              ),
            ],
            const SizedBox(height: 12),
            CampoDetalle(
              Icons.event_available_rounded,
              'Fecha de ingreso',
              formatearFecha(vehiculo.fechaIngreso),
            ),
            CampoDetalle(
              Icons.person_pin_circle_rounded,
              'Conductor asignado',
              vehiculo.identificacionConductor == null ||
                      vehiculo.identificacionConductor!.isEmpty
                  ? 'Sin asignar'
                  : vehiculo.identificacionConductor,
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _cargando
                  ? null
                  : () => Navigator.of(context).pop<Vehiculo>(_vehiculo),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Editar vehículo'),
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

String _describir(Vehiculo vehiculo) {
  final marcaModelo = '${vehiculo.marca} ${vehiculo.modelo}'.trim();
  return <String>[
    if (vehiculo.tipo.isNotEmpty) vehiculo.tipo else 'Sin tipo',
    if (marcaModelo.isNotEmpty) marcaModelo,
  ].join(' · ');
}
