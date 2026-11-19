import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// Implementación para web.
///
/// `Clipboard.setData` de Flutter usa `navigator.clipboard.writeText`, que el
/// navegador rechaza con `PlatformException(copy_fail)` cuando la pestaña no
/// tiene el foco, cuando se deniega el permiso `clipboard-write` o cuando la
/// app corre dentro de un iframe (por ejemplo, el navegador integrado del IDE).
///
/// Por eso, si la API asíncrona falla, se intenta la copia clásica con un
/// `textarea` temporal y `document.execCommand('copy')`.
Future<bool> copiarAlPortapapeles(String texto) async {
  if (await _copiarConApiAsincrona(texto)) return true;
  if (_copiarConExecCommand(texto)) return true;
  return _copiarConFlutter(texto);
}

Future<bool> _copiarConApiAsincrona(String texto) async {
  try {
    await web.window.navigator.clipboard.writeText(texto).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

bool _copiarConExecCommand(String texto) {
  final body = web.document.body;
  if (body == null) return false;

  final area = web.HTMLTextAreaElement()
    ..value = texto
    ..readOnly = true
    ..setAttribute('aria-hidden', 'true');
  area.style
    ..position = 'fixed'
    ..top = '-1000px'
    ..opacity = '0';
  body.appendChild(area);

  try {
    area.select();
    return web.document.execCommand('copy');
  } catch (_) {
    return false;
  } finally {
    area.remove();
  }
}

Future<bool> _copiarConFlutter(String texto) async {
  try {
    await Clipboard.setData(ClipboardData(text: texto));
    return true;
  } on PlatformException {
    return false;
  } catch (_) {
    return false;
  }
}
