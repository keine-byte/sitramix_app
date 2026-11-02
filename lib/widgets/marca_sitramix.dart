import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SitramixIcono extends StatelessWidget {
  const SitramixIcono({this.ancho = 119, super.key});

  final double ancho;

  static const ruta = 'assets/images/sitramix_icono.svg';

  static const proporcion = 98 / 119;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    ruta,
    width: ancho,
    height: ancho * proporcion,
    semanticsLabel: 'SITRAMIX',
  );
}

class SitramixLogo extends StatelessWidget {
  const SitramixLogo({this.ancho = 28, super.key});

  final double ancho;

  static const ruta = 'assets/images/sitramix_logo.svg';

  static const proporcion = 12.2376 / 22.9744;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    ruta,
    width: ancho,
    height: ancho * proporcion,
    semanticsLabel: 'SITRAMIX',
  );
}

class SitramixChip extends StatelessWidget {
  const SitramixChip({
    required this.child,
    this.radio = 12,
    this.relleno = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final double radio;
  final EdgeInsetsGeometry relleno;

  static const color = Color(0x26F28C26);

  @override
  Widget build(BuildContext context) => Container(
    padding: relleno,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radio),
    ),
    child: child,
  );
}
