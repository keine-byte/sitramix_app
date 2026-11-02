import 'dart:convert';

import 'package:sitramix/models/common/json_utils.dart';

enum Rol {
  gerente('GERENTE'),
  asistente('ASISTENTE'),
  asociado('ASOCIADO'),
  desconocido('DESCONOCIDO');

  const Rol(this.apiValue);

  final String apiValue;

  static Rol fromApi(Object? value) {
    final text = parseApiString(value)?.toUpperCase();
    return values.firstWhere(
      (rol) => rol.apiValue == text,
      orElse: () => Rol.desconocido,
    );
  }
}

class Sesion {
  const Sesion({
    required this.token,
    required this.rol,
    this.requiereCambioPassword = false,
    this.identificacion,
    this.nombres,
    this.username,
    this.empresa,
  });

  final String token;
  final Rol rol;
  final bool requiereCambioPassword;
  final String? identificacion;
  final String? nombres;
  final String? username;

  final String? empresa;

  bool get tieneAcceso => token.isNotEmpty && !requiereCambioPassword;

  bool get esAsociado => rol == Rol.asociado;

  factory Sesion.fromJson(Map<String, dynamic> json) => Sesion(
    token: parseApiString(json['token']) ?? '',
    rol: Rol.fromApi(json['rol']),
    requiereCambioPassword:
        parseApiBool(json['requiereCambioPassword']) ?? false,
    identificacion: parseApiString(json['identificacion']),
    nombres: parseApiString(json['nombres']),
    username: parseApiString(json['username']),
    empresa: razonSocial(json['empresa']),
  );

  static String? razonSocial(Object? value) {
    if (value is Map) return parseApiString(value['razonSocial']);
    return parseApiString(value);
  }

  Sesion conNombres(String value) => Sesion(
    token: token,
    rol: rol,
    requiereCambioPassword: requiereCambioPassword,
    identificacion: identificacion,
    nombres: value,
    username: username,
    empresa: empresa,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'token': token,
    'rol': rol.apiValue,
    'requiereCambioPassword': requiereCambioPassword,
    if (identificacion != null) 'identificacion': identificacion,
    if (nombres != null) 'nombres': nombres,
    if (username != null) 'username': username,
    if (empresa != null) 'empresa': <String, dynamic>{'razonSocial': empresa},
  };

  String encode() => jsonEncode(toJson());

  static Sesion? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final sesion = Sesion.fromJson(json);
      return sesion.token.isEmpty ? null : sesion;
    } on FormatException {
      return null;
    }
  }
}
