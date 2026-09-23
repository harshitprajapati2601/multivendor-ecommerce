import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:multivendor_app/providers/auth_provider.dart';
import 'package:multivendor_app/screens/auth/forgot_password_screen.dart';

void main() {
  testWidgets('ForgotPasswordScreen renders initial step correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          child: const ForgotPasswordScreen(email: 'test@example.com'),
        ),
      ),
    );

    expect(find.text('Forgot Your Password?'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Send Reset Code'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
  });
}
