import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:listatareasflutter/main.dart';

void main() {
  testWidgets('login shows validation error for invalid email', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onSignIn: (email, password) async => null,
          onRegister: (email, password) async => null,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'correo-invalido');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Escribe un correo válido'), findsOneWidget);
  });
}
