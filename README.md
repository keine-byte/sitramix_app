# SITRAMIX

Aplicación Flutter para Android, iOS y web con login en español y el diseño del prototipo
funcional de SITRAMIX (encabezados `#111827`, acentos ámbar `#B7791F` y arranque `#265240`).

Ejecutar: `flutter pub get` y `flutter run` con un emulador o dispositivo Android conectado. iOS requiere macOS y Xcode.

## Web y vista previa en teléfono

El proyecto incluye la plataforma web (`web/`, `flutter build web`), así que se puede previsualizar dentro de VS Code con la extensión **Flutter Phone Preview** (marco de iPhone/Android, teclado virtual, capturas).

1. Abre `sitramix.code-workspace` de la raíz del repositorio (la extensión ejecuta `flutter run` en la primera carpeta del workspace, que es `smartbook_app`).
2. `Ctrl + Shift + P` → **Flutter: Iniciar vista previa en teléfono**.

Requisitos, proxy REST y solución de problemas: `docs/VISTA_PREVIA_TELEFONO.md`.

## Diseño (prototipo funcional)

Las pantallas replican `Prototipo funcional_Figma/` (React + Tailwind). La paleta, la
tipografía **IBM Plex Sans** (`assets/fonts`, SIL OFL 1.1) y el tema global viven en
`lib/config/app_theme.dart`; el estado de la migración pantalla por pantalla está en
`docs/DISENO_PANTALLAS.md`.

La pantalla principal (`lib/screens/inicio_screen.dart`) ya es la del prototipo:
encabezado oscuro con el resumen de la operación (asociados, conductores, vehículos y
sanciones activas), etiqueta `GESTIÓN`, rejilla de módulos con contadores y barra de
navegación inferior. Los contadores se leen de la API (primera página de cada listado) y
se muestran como `—` o `100+` cuando el dato no llega o supera la página.

También siguen el prototipo la **pantalla de arranque** (`lib/screens/splash_screen.dart`,
fondo `#265240`, escudo, marca y versión) y el **acceso** (`lib/screens/login_screen.dart`:
encabezado oscuro y hoja blanca con los campos y el botón ámbar). Los primitivos
compartidos del prototipo están en `lib/widgets/prototipo/` (`ProtoField`, `ProtoButton` y
`ProtoSectionLabel`), y la marca en `lib/widgets/marca_sitramix.dart` (`SitramixIcono`,
`SitramixLogo` y `SitramixChip`, con los SVG que trae `Prototipo funcional_Figma/public/`).

## Estructura

- `lib/main.dart`: entrada de la aplicación y rutas iniciales.
- `lib/config/`: tema (`app_theme.dart`), URLs (`app_config.dart`) y endpoints
  (`api_paths.dart`).
- `lib/models/`: entidades por módulo (sesión, asociado, vehículo, planilla, resumen…).
- `lib/routes/`: nombres de ruta.
- `lib/screens/`: pantallas por módulo, formularios, arranque, acceso y la pantalla principal.
- `lib/widgets/`: campos, botones, filas de datos y la marca (`marca_sitramix.dart`);
  `prototipo/` con los primitivos tomados del diseño (`ProtoField`, `ProtoButton`,
  `ProtoSectionLabel`).
- `lib/services/local/`: sesión en almacenamiento seguro.
- `lib/services/remote/`: cliente HTTP y un servicio por módulo de la API.
- `assets/images/`: los dos SVG de la marca (`sitramix_icono.svg` y `sitramix_logo.svg`,
  copiados del prototipo); `assets/fonts/`: IBM Plex Sans.

## Integración

`ApiService` admite GET, POST, PUT y DELETE con JSON, timeout y errores HTTP; la base se
configura con `--dart-define=API_BASE_URL=https://tu-api`. `SecureStorageService` guarda
la sesión (`token`, `rol`, datos del usuario) y las pantallas la rehidratan al arrancar.
