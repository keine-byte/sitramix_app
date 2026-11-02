import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sitramix/models/common/page_query.dart';
import 'package:sitramix/models/resumen/resumen_dashboard.dart';
import 'package:sitramix/models/sancion/sancion.dart';
import 'package:sitramix/models/sesion/sesion.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../routes/app_routes.dart';
import '../services/local/secure_storage_service.dart';
import '../services/remote/afiliaciones_api.dart';
import '../services/remote/api_service.dart';
import '../services/remote/asociados_api.dart';
import '../services/remote/conductores_api.dart';
import '../services/remote/despachos_api.dart';
import '../services/remote/mantenimientos_api.dart';
import '../services/remote/mi_cuenta_api.dart';
import '../services/remote/pagos_api.dart';
import '../services/remote/planillas_api.dart';
import '../services/remote/sanciones_api.dart';
import '../services/remote/tarifas_api.dart';
import '../services/remote/vehiculos_api.dart';
import '../widgets/marca_sitramix.dart';
import '../widgets/prototipo/proto_section_label.dart';
import 'afiliaciones_screen.dart';
import 'asociados_screen.dart';
import 'conductores_screen.dart';
import 'despachos_screen.dart';
import 'mantenimientos_screen.dart';
import 'mi_cuenta_screen.dart';
import 'pagos_screen.dart';
import 'planillas_screen.dart';
import 'sanciones_screen.dart';
import 'tarifas_screen.dart';
import 'vehiculos_screen.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key, this.sesionInicial, this.cargarResumen});

  final Sesion? sesionInicial;

  final Future<ResumenDashboard> Function(Sesion sesion)? cargarResumen;

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final SecureStorageService _sessionStorage = const SecureStorageService();

  Sesion? _sesion;
  ResumenDashboard _resumen = ResumenDashboard.vacio;
  bool _cargandoResumen = false;

  @override
  void initState() {
    super.initState();
    final inicial = widget.sesionInicial;
    if (inicial == null) {
      _cargarSesion();
    } else {
      _sesion = inicial;
      _refrescarResumen();
    }
  }

  Future<void> _cargarSesion() async {
    final sesion = await _sessionStorage.readSesion();
    if (!mounted || sesion == null) return;
    setState(() => _sesion = sesion);
    await _refrescarResumen();
  }

  Future<void> _cerrarSesion() async {
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    await _sessionStorage.clear();
  }

  bool get _esPersonal =>
      _sesion?.rol == Rol.gerente || _sesion?.rol == Rol.asistente;

  bool get _tieneAcceso => _sesion?.tieneAcceso ?? false;

  bool get _puedeGenerarCredencial => _sesion?.rol == Rol.gerente;

  bool get _puedeVerTarifas => _puedeGenerarCredencial;

  bool get _puedeVerMiCuenta => _sesion?.rol == Rol.asociado;

  String get _nombre => _nombreRegistrado ?? _etiquetaRol;

  String? get _nombreRegistrado {
    final sesion = _sesion;
    final nombres = sesion?.nombres?.trim();
    if (nombres != null && nombres.isNotEmpty) return nombres;

    final usuario = sesion?.username?.trim();
    if (usuario == null || usuario.isEmpty) return null;
    if (usuario == sesion?.identificacion) return null;
    if (RegExp(r'^\d+$').hasMatch(usuario)) return null;
    return usuario;
  }

  String get _etiquetaRol => switch (_sesion?.rol) {
    Rol.gerente => 'Gerente',
    Rol.asistente => 'Asistente',
    Rol.asociado => 'Asociado',
    _ => 'Invitado',
  };

  Future<ResumenDashboard> _resumenDesdeApi(Sesion sesion) async {
    final api = ApiService(baseUrl: AppConfig.apiBaseUrl);
    const query = PageQuery(pageSize: AppConfig.maxPageSize);

    final asociadosApi = AsociadosApi(api: api, token: sesion.token);
    final afiliacionesApi = AfiliacionesApi(api: api, token: sesion.token);
    final conductoresApi = ConductoresApi(api: api, token: sesion.token);
    final sancionesApi = SancionesApi(api: api, token: sesion.token);
    final vehiculosApi = VehiculosApi(api: api, token: sesion.token);
    final tarifasApi = TarifasApi(api: api, token: sesion.token);
    final planillasApi = PlanillasApi(api: api, token: sesion.token);
    final despachosApi = DespachosApi(api: api, token: sesion.token);
    final pagosApi = PagosApi(api: api, token: sesion.token);
    final mantenimientosApi = MantenimientosApi(api: api, token: sesion.token);

    final totalesOperacion = (
      _contar(() => asociadosApi.listar(query: query)),
      _contar(() => afiliacionesApi.listar(query: query)),
      _contar(() => conductoresApi.listar(query: query)),
      _contar(
        () => sancionesApi.listar(query: query, estado: EstadoSancion.activa),
      ),
      _contar(() => vehiculosApi.listar(query: query)),
    ).wait;

    final totalesAdministracion = (
      _puedeVerTarifas
          ? _contar(() => tarifasApi.listar(query: query))
          : Future<int?>.value(),
      _contar(() => planillasApi.listar(query: query)),
      _contar(() => despachosApi.listar(query: query)),
      _contar(() => pagosApi.listar(query: query)),
      _contar(() => mantenimientosApi.listar(query: query)),
    ).wait;

    final (asociados, afiliaciones, conductores, sanciones, vehiculos) =
        await totalesOperacion;
    final (tarifas, planillas, despachos, pagos, mantenimientos) =
        await totalesAdministracion;

    return ResumenDashboard(
      asociados: asociados,
      afiliaciones: afiliaciones,
      conductores: conductores,
      sanciones: sanciones,
      vehiculos: vehiculos,
      tarifas: tarifas,
      planillas: planillas,
      despachos: despachos,
      pagos: pagos,
      mantenimientos: mantenimientos,
    );
  }

  Future<int?> _contar(Future<List<dynamic>> Function() listar) async {
    try {
      final filas = await listar();
      return filas.length;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refrescarResumen() async {
    final sesion = _sesion;
    if (sesion == null || !sesion.tieneAcceso || !_esPersonal) {
      if (mounted) setState(() => _resumen = ResumenDashboard.vacio);
      return;
    }
    setState(() => _cargandoResumen = true);
    ResumenDashboard resumen;
    try {
      resumen = await (widget.cargarResumen ?? _resumenDesdeApi)(sesion);
    } catch (_) {
      resumen = ResumenDashboard.vacio;
    }
    if (!mounted) return;
    setState(() {
      _resumen = resumen;
      _cargandoResumen = false;
    });
  }

  String? _tokenParaAbrir() {
    final sesion = _sesion;
    if (sesion == null || !sesion.tieneAcceso) {
      _mostrarMensaje('Vuelve a iniciar sesión para continuar.');
      return null;
    }
    return sesion.token;
  }

  Future<void> _abrir(Widget Function() construir) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => construir()));
  }

  Future<void> _abrirPlanillas() async {
    final token = _tokenParaAbrir();
    if (token == null) return;
    await _abrir(
      () => PlanillasScreen(
        api: PlanillasApi(
          api: ApiService(baseUrl: AppConfig.apiBaseUrl),
          token: token,
        ),
      ),
    );
  }

  Future<void> _abrirAsociados() async {
    final token = _tokenParaAbrir();
    if (token == null) return;
    await _abrir(
      () => AsociadosScreen(
        api: AsociadosApi(
          api: ApiService(baseUrl: AppConfig.apiBaseUrl),
          token: token,
        ),
        puedeGenerarCredencial: _puedeGenerarCredencial,
      ),
    );
  }

  Future<void> _abrirConductores() async {
    final token = _tokenParaAbrir();
    if (token == null) return;
    await _abrir(
      () => ConductoresScreen(
        api: ConductoresApi(
          api: ApiService(baseUrl: AppConfig.apiBaseUrl),
          token: token,
        ),
      ),
    );
  }

  Future<void> _abrirVehiculos() async {
    final token = _tokenParaAbrir();
    if (token == null) return;
    await _abrir(
      () => VehiculosScreen(
        api: VehiculosApi(
          api: ApiService(baseUrl: AppConfig.apiBaseUrl),
          token: token,
        ),
      ),
    );
  }

  Future<void> _abrirAfiliaciones() async {
    final token = _tokenParaAbrir();
    if (token == null) return;
    await _abrir(
      () => AfiliacionesScreen(
        api: AfiliacionesApi(
          api: ApiService(baseUrl: AppConfig.apiBaseUrl),
          token: token,
        ),
      ),
    );
  }

  Future<void> _abrirPagos() async {
    final token = _tokenParaAbrir();
    if (token == null) return;
    await _abrir(
      () => PagosScreen(
        api: PagosApi(
          api: ApiService(baseUrl: AppConfig.apiBaseUrl),
          token: token,
        ),
      ),
    );
  }

  Future<void> _abrirMantenimientos() async {
    final token = _tokenParaAbrir();
    if (token == null) return;
    await _abrir(
      () => MantenimientosScreen(
        api: MantenimientosApi(
          api: ApiService(baseUrl: AppConfig.apiBaseUrl),
          token: token,
        ),
      ),
    );
  }

  Future<void> _abrirTarifas() async {
    final token = _tokenParaAbrir();
    if (token == null) return;
    await _abrir(
      () => TarifasScreen(
        api: TarifasApi(
          api: ApiService(baseUrl: AppConfig.apiBaseUrl),
          token: token,
        ),
      ),
    );
  }

  Future<void> _abrirDespachos() async {
    final token = _tokenParaAbrir();
    if (token == null) return;
    await _abrir(
      () => DespachosScreen(
        api: DespachosApi(
          api: ApiService(baseUrl: AppConfig.apiBaseUrl),
          token: token,
        ),
      ),
    );
  }

  Future<void> _abrirSanciones() async {
    final token = _tokenParaAbrir();
    if (token == null) return;
    await _abrir(
      () => SancionesScreen(
        api: SancionesApi(
          api: ApiService(baseUrl: AppConfig.apiBaseUrl),
          token: token,
        ),
      ),
    );
  }

  Future<void> _abrirMiCuenta() async {
    final token = _tokenParaAbrir();
    if (token == null) return;
    await _abrir(
      () => MiCuentaScreen(
        api: MiCuentaApi(
          api: ApiService(baseUrl: AppConfig.apiBaseUrl),
          token: token,
        ),
      ),
    );
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  List<_Modulo> _modulos() {
    if (!_tieneAcceso) return <_Modulo>[];
    if (_puedeVerMiCuenta) {
      return <_Modulo>[
        _Modulo(
          id: 'mi-cuenta',
          icono: Icons.person_rounded,
          titulo: 'Mi cuenta',
          onTap: _abrirMiCuenta,
        ),
      ];
    }
    return <_Modulo>[
      _Modulo(
        id: 'asociados',
        icono: Icons.groups_rounded,
        titulo: 'Asociados',
        contador: _resumen.asociados,
        onTap: _abrirAsociados,
      ),
      _Modulo(
        id: 'afiliaciones',
        icono: Icons.handshake_rounded,
        titulo: 'Afiliaciones',
        contador: _resumen.afiliaciones,
        onTap: _abrirAfiliaciones,
      ),
      _Modulo(
        id: 'conductores',
        icono: Icons.badge_rounded,
        titulo: 'Conductores',
        contador: _resumen.conductores,
        onTap: _abrirConductores,
      ),
      _Modulo(
        id: 'sanciones',
        icono: Icons.gavel_rounded,
        titulo: 'Sanciones',
        contador: _resumen.sanciones,
        onTap: _abrirSanciones,
      ),
      _Modulo(
        id: 'vehiculos',
        icono: Icons.directions_bus_rounded,
        titulo: 'Vehículos',
        contador: _resumen.vehiculos,
        onTap: _abrirVehiculos,
      ),
      if (_puedeVerTarifas)
        _Modulo(
          id: 'tarifas',
          icono: Icons.sell_rounded,
          titulo: 'Tarifas',
          contador: _resumen.tarifas,
          onTap: _abrirTarifas,
        ),
      _Modulo(
        id: 'planillas',
        icono: Icons.receipt_long_rounded,
        titulo: 'Planillas',
        contador: _resumen.planillas,
        onTap: _abrirPlanillas,
      ),
      _Modulo(
        id: 'despachos',
        icono: Icons.route_rounded,
        titulo: 'Despachos',
        contador: _resumen.despachos,
        onTap: _abrirDespachos,
      ),
      _Modulo(
        id: 'pagos',
        icono: Icons.payments_rounded,
        titulo: 'Pagos',
        contador: _resumen.pagos,
        onTap: _abrirPagos,
      ),
      _Modulo(
        id: 'mantenimientos',
        icono: Icons.build_rounded,
        titulo: 'Mantenimientos',
        contador: _resumen.mantenimientos,
        onTap: _abrirMantenimientos,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final modulos = _modulos();
    return Scaffold(
      backgroundColor: AppTheme.gray,
      body: Column(
        children: [
          _encabezado(),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.amber,
              onRefresh: _refrescarResumen,
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: ProtoSectionLabel(
                      texto: 'Gestión',
                      cargando: _cargandoResumen,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _rejilla(modulos),
                  ),
                ],
              ),
            ),
          ),
          _barraNavegacion(),
        ],
      ),
    );
  }

  Widget _encabezado() => Container(
    width: double.infinity,
    color: AppTheme.dark,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bienvenido,',
                        style: TextStyle(fontSize: 10, color: AppTheme.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _chipRol(),
                    ],
                  ),
                ),
                SitramixChip(
                  radio: 10,
                  relleno: const EdgeInsets.all(6),
                  child: const SitramixLogo(ancho: 24),
                ),
              ],
            ),
            if (_esPersonal) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      clave: 'asociados',
                      etiqueta: 'Asociados',
                      valor: _resumen.asociados,
                      detalle: 'registrados',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      clave: 'conductores',
                      etiqueta: 'Conductores',
                      valor: _resumen.conductores,
                      detalle: 'registrados',
                      color: AppTheme.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      clave: 'vehiculos',
                      etiqueta: 'Vehículos',
                      valor: _resumen.vehiculos,
                      detalle: 'registrados',
                      color: AppTheme.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      clave: 'sanciones',
                      etiqueta: 'Sanciones',
                      valor: _resumen.sanciones,
                      detalle: 'activas',
                      color: AppTheme.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _chipRol() {
    final texto = _sesion?.rol.apiValue ?? 'SIN SESIÓN';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.amberSuave,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppTheme.amber, width: 0.9),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppTheme.amber,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _rejilla(List<_Modulo> modulos) {
    if (modulos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          _sesion == null
              ? 'Cargando tu sesión…'
              : 'Vuelve a iniciar sesión para ver los módulos.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppTheme.muted),
        ),
      );
    }
    final filas = <Widget>[];
    for (var i = 0; i < modulos.length; i += 2) {
      final izquierda = modulos[i];
      final derecha = i + 1 < modulos.length ? modulos[i + 1] : null;
      if (filas.isNotEmpty) filas.add(const SizedBox(height: 8));
      filas.add(
        Row(
          children: [
            Expanded(child: _ModuloTile(modulo: izquierda)),
            const SizedBox(width: 8),
            Expanded(
              child: derecha == null
                  ? const SizedBox.shrink()
                  : _ModuloTile(modulo: derecha),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: filas,
    );
  }

  Widget _barraNavegacion() => Container(
    decoration: const BoxDecoration(
      color: AppTheme.dark,
      border: Border(top: BorderSide(color: AppTheme.navDivider, width: 0.9)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(
          children: [
            _itemNav(
              id: 'inicio',
              icono: Icons.grid_view_rounded,
              etiqueta: 'Inicio',
              activo: true,
              onTap: () {},
            ),
            if (_esPersonal) ...<Widget>[
              _itemNav(
                id: 'vehiculos',
                icono: Icons.directions_bus_rounded,
                etiqueta: 'Vehículos',
                onTap: _abrirVehiculos,
              ),
              _itemNav(
                id: 'planillas',
                icono: Icons.receipt_long_rounded,
                etiqueta: 'Planillas',
                onTap: _abrirPlanillas,
              ),
            ],
            if (_puedeVerMiCuenta)
              _itemNav(
                id: 'mi-cuenta',
                icono: Icons.person_rounded,
                etiqueta: 'Mi cuenta',
                onTap: _abrirMiCuenta,
              ),
            _itemNav(
              id: 'perfil',
              icono: Icons.account_circle_outlined,
              etiqueta: 'Perfil',
              onTap: _mostrarPerfil,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _itemNav({
    required String id,
    required IconData icono,
    required String etiqueta,
    required VoidCallback onTap,
    bool activo = false,
  }) {
    final color = activo ? AppTheme.amber : AppTheme.muted;
    return Expanded(
      child: InkWell(
        key: ValueKey('nav-$id'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(height: 2),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarPerfil() async {
    final sesion = _sesion;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Perfil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sesión activa en este dispositivo.',
                style: TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
              const SizedBox(height: 14),
              if (_nombreRegistrado != null)
                _datoPerfil('Nombre', _nombreRegistrado!),
              _datoPerfil('Rol', sesion?.rol.apiValue ?? 'SIN SESIÓN'),
              if (sesion?.empresa != null)
                _datoPerfil('Empresa', sesion!.empresa!),
              if (sesion?.identificacion != null)
                _datoPerfil('Identificación', sesion!.identificacion!),
              if (sesion?.username != null)
                _datoPerfil('Usuario', sesion!.username!),
              const SizedBox(height: 16),
              SizedBox(
                height: 36,
                child: FilledButton(
                  key: const ValueKey('perfil-cerrar-sesion'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.amber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _cerrarSesion();
                  },
                  child: const Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datoPerfil(String etiqueta, String valor) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppTheme.gray, width: 0.9)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 9, color: AppTheme.muted),
        ),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.dark,
          ),
        ),
      ],
    ),
  );
}

class _Modulo {
  _Modulo({
    required this.id,
    required this.icono,
    required this.titulo,
    required this.onTap,
    this.contador,
  });

  final String id;
  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  final int? contador;
}

class _ModuloTile extends StatelessWidget {
  const _ModuloTile({required this.modulo});

  final _Modulo modulo;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 92,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('modulo-${modulo.id}'),
        onTap: modulo.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(modulo.icono, size: 20, color: AppTheme.dark),
              const SizedBox(height: 6),
              Text(
                modulo.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dark,
                ),
              ),
              const SizedBox(height: 6),
              _ChipContador(valor: modulo.contador),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChipContador extends StatelessWidget {
  const _ChipContador({required this.valor});

  final int? valor;

  static String texto(int? valor) {
    if (valor == null) return '—';
    return valor >= AppConfig.maxPageSize
        ? '${AppConfig.maxPageSize}+'
        : '$valor';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.gray,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(
        color: valor == null ? AppTheme.border : AppTheme.amber,
        width: 0.9,
      ),
    ),
    child: Text(
      texto(valor),
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: AppTheme.dark,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.clave,
    required this.etiqueta,
    required this.valor,
    required this.detalle,
    this.color = AppTheme.amber,
  });

  final String clave;
  final String etiqueta;
  final int? valor;
  final String detalle;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    key: ValueKey('stat-$clave'),
    borderRadius: BorderRadius.circular(8),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: color),
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiqueta,
                    style: const TextStyle(fontSize: 9, color: AppTheme.muted),
                  ),
                  Text(
                    _ChipContador.texto(valor),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.dark,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    detalle,
                    style: const TextStyle(fontSize: 9, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
