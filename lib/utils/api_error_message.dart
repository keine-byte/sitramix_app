import '../services/remote/api_service.dart';

String mensajeDeApi(ApiException error) => error.statusCode == null
    ? 'No se pudo conectar con la API. Revisa tu conexión.'
    : error.message;
