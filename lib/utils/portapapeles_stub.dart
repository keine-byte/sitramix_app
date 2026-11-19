import 'package:flutter/services.dart';

/// Implementación para móvil y escritorio.
Future<bool> copiarAlPortapapeles(String texto) async {
  try {
    await Clipboard.setData(ClipboardData(text: texto));
    return true;
  } on PlatformException {
    return false;
  } catch (_) {
    return false;
  }
}
