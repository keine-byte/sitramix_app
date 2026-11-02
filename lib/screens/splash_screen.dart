import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/marca_sitramix.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    required this.rutaSiguiente,
    this.duracion = const Duration(milliseconds: 900),
    super.key,
  });

  final String rutaSiguiente;

  final Duration duracion;

  static const version = '2.4.1';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _temporizador;
  bool _continuo = false;

  @override
  void initState() {
    super.initState();
    _temporizador = Timer(widget.duracion, _continuar);
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  void _continuar() {
    if (_continuo || !mounted) return;
    _continuo = true;
    _temporizador?.cancel();
    Navigator.of(context).pushReplacementNamed(widget.rutaSiguiente);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.splash,
    body: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _continuar,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      alignment: Alignment.center,
                      child: const SitramixIcono(ancho: 119),
                    ),
                    const SizedBox(height: 20),
                    const Column(
                      children: [
                        Text(
                          'SITRAMIX',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.44,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'SISTEMA DE TRANSPORTE MIXTO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xCCFFFFFF),
                            letterSpacing: 0.9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _punto(const Color(0x59B7791F)),
                        const SizedBox(width: 6),
                        _punto(AppTheme.amber),
                        const SizedBox(width: 6),
                        _punto(const Color(0x59B7791F)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Text(
                'v${SplashScreen.version} · Cooperativa SITRAMIX',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xCCFFFFFF),
                  letterSpacing: 0.36,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _punto(Color color) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}
