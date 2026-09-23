import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:multivendor_app/providers/auth_provider.dart';
import 'package:multivendor_app/screens/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders Forgot password option', (WidgetTester tester) async {
    final provider = AuthProvider()..status = AuthStatus.unauthenticated;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: const LoginScreen(),
        ),
      ),
    );

    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
