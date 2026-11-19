/// Copia texto al portapapeles del sistema.
///
/// En web se intenta primero la API asíncrona del navegador y, si el navegador
/// la bloquea, se recurre a `document.execCommand('copy')`. En el resto de
/// plataformas usa `Clipboard.setData` de Flutter.
///
/// Devuelve `true` cuando el texto quedó en el portapapeles.
library;

export 'portapapeles_stub.dart'
    if (dart.library.js_interop) 'portapapeles_web.dart';
