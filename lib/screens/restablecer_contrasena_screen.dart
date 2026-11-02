import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../routes/app_routes.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/fields/custom_text_field.dart';
import '../widgets/marca_sitramix.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _requestResetCode() {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'El envío del código de restablecimiento aún no está disponible.',
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo electrónico.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Ingresa un correo electrónico válido.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 40,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.dark,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const SitramixLogo(ancho: 150),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Restablecer Contraseña',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 40),
                        CustomTextField(
                          controller: _emailController,
                          label: 'Correo electrónico',
                          hintText: 'usuario@yopmail.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          validator: _validateEmail,
                          onFieldSubmitted: (_) => _requestResetCode(),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: 'Solicitar código de restablecimiento',
                          onPressed: _requestResetCode,
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => Navigator.of(context)
                              .pushNamedAndRemoveUntil(
                                AppRoutes.login,
                                (route) => false,
                              ),
                          child: const Text(
                            '← Volver al inicio de sesión',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                '© ${DateTime.now().year} SITRAMIX · Cooperativa',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF77798B), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
