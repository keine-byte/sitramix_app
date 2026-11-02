import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitramix/main.dart';

void main() {
  testWidgets('Valida campos de acceso', (tester) async {
    await tester.pumpWidget(const SitramixApp());
    await tester.tap(find.byKey(const ValueKey('login-enviar')));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu usuario.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'aperez');
    await tester.enterText(find.byType(TextFormField).last, 'clave');
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('login-enviar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('al conectar la API'), findsOneWidget);
  });
  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('Diseño adaptable a $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const SitramixApp());
      await tester.pumpAndSettle();
      expect(find.text('USUARIO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
