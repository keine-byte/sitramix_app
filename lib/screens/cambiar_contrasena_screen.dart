import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../models/sesion/sesion.dart';
import '../routes/app_routes.dart';
import '../services/local/secure_storage_service.dart';
import '../services/local/session_storage.dart';
import '../services/remote/api_service.dart';
import '../services/remote/auth_api.dart';
import '../utils/api_error_message.dart';
import '../utils/sesion_expirada.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/forms/form_fields.dart';
import '../widgets/prototipo/proto_field.dart';

/// Permite cambiar la contraseña cuando el login llega con
/// `requiereCambioPassword = true` (por ejemplo, credenciales temporales).
class CambiarContrasenaScreen extends StatefulWidget {
  const CambiarContrasenaScreen({
    required this.sesion,
    this.api,
    this.almacenamiento,
    super.key,
  });

  final Sesion sesion;

  final AuthApi? api;

  final SessionStorage? almacenamiento;

  @override
  State<CambiarContrasenaScreen> createState() =>
      _CambiarContrasenaScreenState();
}

class _CambiarContrasenaScreenState extends State<CambiarContrasenaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nuevaController = TextEditingController();
  final _confirmacionController = TextEditingController();

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nuevaController.dispose();
    _confirmacionController.dispose();
    super.dispose();
  }

  String? _validarNueva(String? value) {
    if ((value ?? '').isEmpty) return 'Ingresa la nueva contraseña.';
    return null;
  }

  String? _validarConfirmacion(String? value) {
    if ((value ?? '').isEmpty) return 'Repite la nueva contraseña.';
    if (value != _nuevaController.text) return 'Las contraseñas no coinciden.';
    return null;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final authApi =
        widget.api ??
        AuthApi(
          api: ApiService(baseUrl: AppConfig.apiBaseUrl),
          token: widget.sesion.token,
        );
    final storage = widget.almacenamiento ?? const SecureStorageService();

    try {
      final sesion = await authApi.cambiarPassword(
        nuevaPassword: _nuevaController.text,
        confirmacionPassword: _confirmacionController.text,
      );
      if (!mounted) return;

      await storage.saveSesion(sesion);
      if (!mounted) return;

      setState(() => _guardando = false);
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (_) => false,
        arguments: sesion,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (await cerrarSesionSiExpirada(context, error, storage: storage)) {
        return;
      }
      setState(() => _error = mensajeDeApi(error));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('Cambiar contraseña'),
      titleTextStyle: const TextStyle(
        color: AppTheme.secondary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Debes cambiar tu contraseña temporal para continuar.',
                    style: TextStyle(color: Color(0xFF77798B), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ProtoField(
                    key: const ValueKey('cambiar-nueva'),
                    controller: _nuevaController,
                    label: 'Nueva contraseña',
                    esPassword: true,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    validator: _validarNueva,
                  ),
                  const SizedBox(height: 12),
                  ProtoField(
                    key: const ValueKey('cambiar-confirmacion'),
                    controller: _confirmacionController,
                    label: 'Confirmar contraseña',
                    esPassword: true,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    validator: _validarConfirmacion,
                    onFieldSubmitted: (_) => _guardar(),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) AvisoFormulario(_error!),
                  PrimaryButton(
                    key: const ValueKey('cambiar-guardar'),
                    label: 'Guardar nueva contraseña',
                    onPressed: _guardar,
                    isLoading: _guardando,
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
