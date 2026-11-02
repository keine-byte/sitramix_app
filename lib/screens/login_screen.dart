import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/login/login_request.dart';
import '../routes/app_routes.dart';
import '../services/local/secure_storage_service.dart';
import '../services/local/session_storage.dart';
import '../services/remote/api_service.dart';
import '../services/remote/login_service.dart';
import '../services/remote/nombre_usuario_service.dart';
import '../widgets/marca_sitramix.dart';
import '../widgets/prototipo/proto_button.dart';
import '../widgets/prototipo/proto_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.servicio,
    this.almacenamiento,
    this.nombres,
  });

  final LoginService? servicio;
  final SessionStorage? almacenamiento;

  final NombreUsuarioService? nombres;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const double _anchoMaximo = 420;

  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  late final LoginService _loginService = widget.servicio ?? LoginService();
  late final SessionStorage _sessionStorage =
      widget.almacenamiento ?? const SecureStorageService();
  late final NombreUsuarioService _nombreService =
      widget.nombres ?? NombreUsuarioService();

  bool _cargando = false;

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validarUsuario(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Ingresa tu usuario.';
    return null;
  }

  String? _validarPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Ingresa tu contraseña.';
    return null;
  }

  Future<void> _login() async {
    if (_cargando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _cargando = true);
    try {
      final sesion = await _loginService.login(
        LoginRequest(
          username: _usuarioController.text.trim(),
          password: _passwordController.text,
        ),
      );
      if (!mounted) return;

      if (sesion.requiereCambioPassword) {
        _mostrarError(
          'Debes cambiar tu contraseña antes de continuar.',
          esError: false,
        );
        return;
      }

      await _sessionStorage.saveSesion(sesion);
      if (!mounted) return;

      final conNombre = await _nombreService.completar(sesion);
      if (!mounted) return;
      if (conNombre.nombres != sesion.nombres) {
        await _sessionStorage.saveSesion(conNombre);
        if (!mounted) return;
      }

      setState(() => _cargando = false);
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (_) => false,
        arguments: conNombre,
      );
    } on ApiException catch (error) {
      _mostrarError(
        error.body == null
            ? 'No se pudo iniciar sesión: error al conectar la API. '
                  '${error.message}'
            : 'No se pudo iniciar sesión. ${error.message}',
      );
    } catch (_) {
      _mostrarError('No se pudo iniciar sesión: error al conectar la API.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String mensaje, {bool esError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje, style: const TextStyle(fontSize: 11)),
          backgroundColor: esError ? AppTheme.dark : AppTheme.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Column(
      children: [
        _encabezado(),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -10),
            child: _hoja(),
          ),
        ),
      ],
    ),
  );

  Widget _encabezado() => Container(
    width: double.infinity,
    color: AppTheme.dark,
    child: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _anchoMaximo + 40),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SitramixChip(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Center(child: SitramixLogo(ancho: 28)),
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SITRAMIX',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.13,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          'TRANSPORTE MIXTO',
                          style: TextStyle(
                            fontSize: 8,
                            color: AppTheme.muted,
                            letterSpacing: 0.5,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Iniciar sesión',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ingresa con tu cuenta de cooperativa',
                  style: TextStyle(fontSize: 10, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _hoja() => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      boxShadow: [
        BoxShadow(
          color: Color(0x1A1E1B16),
          blurRadius: 6,
          offset: Offset(0, -3),
        ),
      ],
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _anchoMaximo),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProtoField(
                    key: const ValueKey('login-usuario'),
                    controller: _usuarioController,
                    label: 'Usuario',
                    hintText: 'usuario.apellido',
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    autocorrect: false,
                    validator: _validarUsuario,
                  ),
                  const SizedBox(height: 10),
                  ProtoField(
                    key: const ValueKey('login-password'),
                    controller: _passwordController,
                    label: 'Contraseña',
                    esPassword: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    autocorrect: false,
                    validator: _validarPassword,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _cargando
                          ? null
                          : () =>
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.resetPassword),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.amber,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 20),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '¿Olvidé mi contraseña?',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ProtoButton(
                    key: const ValueKey('login-enviar'),
                    label: 'Iniciar sesión',
                    onPressed: _login,
                    cargando: _cargando,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sistema exclusivo para miembros de la Cooperativa',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: AppTheme.border),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
