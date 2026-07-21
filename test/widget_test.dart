import 'package:flutter_test/flutter_test.dart';
import 'package:hola_flutter/main.dart'; // Asegúrate de que importe tu main.dart

void main() {
  testWidgets('Carga la pantalla de Login', (WidgetTester tester) async {
    // Construye tu nueva app
    await tester.pumpWidget(const EcoHomeApp());

    // Verifica que el texto de Login aparece
    expect(find.text('Login - EcoHome Store'), findsOneWidget);
  });
}