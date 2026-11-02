import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/asociado/asociado.dart';
import '../models/common/page_query.dart';
import '../services/remote/api_service.dart';
import '../services/remote/asociados_api.dart';
import '../utils/api_error_message.dart';
import '../utils/fechas.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/data_rows.dart';
import '../widgets/fields/custom_text_field.dart';
import 'formulario_asociado_screen.dart';

class AsociadosScreen extends StatefulWidget {
  const AsociadosScreen({
    required this.api,
    this.puedeGenerarCredencial = true,
    super.key,
  });

  final AsociadosApi api;

  final bool puedeGenerarCredencial;

  @override
  State<AsociadosScreen> createState() => _AsociadosScreenState();
}

class _AsociadosScreenState extends State<AsociadosScreen> {
  static const int _pageSize = 20;

  final TextEditingController _nombresController = TextEditingController();

  final List<Asociado> _asociados = <Asociado>[];

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
        if (reiniciar) _asociados.clear();
        _asociados.addAll(resultado);
        _hayMas = query.hasNext(resultado.length);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      final mensaje = mensajeDeApi(error);
      setState(() => _error = mensaje);
      if (_asociados.isNotEmpty) _mostrarMensaje(mensaje);
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

  Future<void> _abrirDetalle(Asociado asociado) async {
    FocusScope.of(context).unfocus();
    final aEditar = await showModalBottomSheet<Asociado>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleAsociado(
        asociado: asociado,
        api: widget.api,
        puedeGenerarCredencial: widget.puedeGenerarCredencial,
      ),
    );
    if (aEditar == null || !mounted) return;
    await _abrirFormulario(asociado: aEditar);
  }

  Future<void> _abrirFormulario({Asociado? asociado}) async {
    final guardado = await Navigator.of(context).push<Asociado>(
      MaterialPageRoute<Asociado>(
        builder: (_) =>
            FormularioAsociadoScreen(api: widget.api, asociado: asociado),
      ),
    );
    if (guardado == null || !mounted) return;
    _mostrarMensaje(
      asociado == null
          ? 'Asociado ${guardado.identificacion} registrado.'
          : 'Asociado ${guardado.identificacion} actualizado.',
    );
    await _consultar();
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Asociados'),
      titleTextStyle: const TextStyle(
        color: AppTheme.secondary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      actions: [
        IconButton(
          tooltip: 'Nuevo asociado',
          onPressed: _abrirFormulario,
          icon: const Icon(Icons.person_add_alt_1_rounded),
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
    if (_cargando && _asociados.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_asociados.isEmpty) {
      return _error != null ? _vistaError() : _vistaVacia();
    }
    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _asociados.length + (_hayMas ? 1 : 0),
        itemBuilder: (context, index) => index >= _asociados.length
            ? _botonCargarMas()
            : _tarjeta(_asociados[index]),
      ),
    );
  }

  Widget _vistaVacia() => _mensaje(
    icon: Icons.groups_outlined,
    titulo: 'Sin asociados',
    detalle: 'No hay asociados para estos filtros.',
    accion: TextButton(
      onPressed: _limpiarFiltros,
      child: const Text('Limpiar filtros'),
    ),
  );

  Widget _vistaError() => _mensaje(
    icon: Icons.cloud_off_rounded,
    titulo: 'No se pudieron cargar los asociados',
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

  Widget _tarjeta(Asociado asociado) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
    child: InkWell(
      onTap: () => _abrirDetalle(asociado),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    asociado.nombres.isEmpty ? 'Sin nombre' : asociado.nombres,
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
                  asociado.activo ? 'ACTIVO' : 'INACTIVO',
                  color: asociado.activo
                      ? const Color(0xFF1F9D55)
                      : const Color(0xFFB26A00),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DatoFila(Icons.badge_rounded, asociado.identificacion),
            if (asociado.celular != null) ...[
              const SizedBox(height: 6),
              DatoFila(Icons.phone_rounded, asociado.celular!),
            ],
            if (asociado.correo != null) ...[
              const SizedBox(height: 6),
              DatoFila(Icons.mail_rounded, asociado.correo!),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DetalleAsociado extends StatefulWidget {
  const _DetalleAsociado({
    required this.asociado,
    required this.api,
    required this.puedeGenerarCredencial,
  });

  final Asociado asociado;
  final AsociadosApi api;
  final bool puedeGenerarCredencial;

  @override
  State<_DetalleAsociado> createState() => _DetalleAsociadoState();
}

class _DetalleAsociadoState extends State<_DetalleAsociado> {
  late Asociado _asociado = widget.asociado;

  CredencialTemporal? _credencial;
  bool _cargando = false;
  bool _generando = false;
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
        widget.asociado.identificacion,
      );
      if (!mounted) return;
      setState(() => _asociado = detalle);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error)) return;
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _generarCredencial() async {
    setState(() => _generando = true);
    try {
      final credencial = await widget.api.generarCredencialTemporal(
        _asociado.identificacion,
      );
      if (!mounted) return;
      setState(() => _credencial = credencial);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeDeApi(error))));
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _copiarCredencial() async {
    final credencial = _credencial;
    if (credencial == null) return;
    await Clipboard.setData(
      ClipboardData(
        text:
            'Usuario: ${credencial.username}\n'
            'Contraseña: ${credencial.passwordTemporal}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Credencial copiada.')));
  }

  @override
  Widget build(BuildContext context) {
    final asociado = _asociado;
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
                    asociado.nombres.isEmpty ? 'Sin nombre' : asociado.nombres,
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Etiqueta(
                  asociado.activo ? 'ACTIVO' : 'INACTIVO',
                  color: asociado.activo
                      ? const Color(0xFF1F9D55)
                      : const Color(0xFFB26A00),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Identificación ${asociado.identificacion}',
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
            CampoDetalle(Icons.phone_rounded, 'Celular', asociado.celular),
            CampoDetalle(Icons.mail_rounded, 'Correo', asociado.correo),
            CampoDetalle(
              Icons.cake_rounded,
              'Fecha de nacimiento',
              formatearFecha(asociado.fechaNacimiento),
            ),
            CampoDetalle(
              Icons.login_rounded,
              'Fecha de ingreso',
              formatearFecha(asociado.fechaIngreso),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _cargando || _generando
                  ? null
                  : () => Navigator.of(context).pop<Asociado>(_asociado),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Editar asociado'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.puedeGenerarCredencial) ...[
              const SizedBox(height: 8),
              if (_credencial == null)
                FilledButton.icon(
                  onPressed: _generando ? null : _generarCredencial,
                  icon: _generando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.key_rounded, size: 18),
                  label: const Text('Generar credencial temporal'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                )
              else
                _credencialTemporal(_credencial!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _credencialTemporal(CredencialTemporal credencial) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F8FC),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E7EF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Credencial temporal',
          style: TextStyle(
            color: AppTheme.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text('Usuario: ${credencial.username}'),
        const SizedBox(height: 4),
        Text('Contraseña: ${credencial.passwordTemporal}'),
        const SizedBox(height: 10),
        const Text(
          'Cópiala ahora: se muestra una sola vez y regenerarla invalida el '
          'acceso anterior.',
          style: TextStyle(fontSize: 12, color: Color(0xFF77798B)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _copiarCredencial,
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copiar credencial'),
        ),
      ],
    ),
  );
}
