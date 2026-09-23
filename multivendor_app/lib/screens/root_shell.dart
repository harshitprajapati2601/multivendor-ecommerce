import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_models.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'admin/admin_shell.dart';
import 'auth/login_screen.dart';
import 'customer/customer_shell.dart';
import 'seller/seller_shell.dart';
import 'splash_screen.dart';

/// Watches [AuthProvider] and swaps between the login flow and the
/// correct role-based shell — this is the single source of truth for
/// "what should be on screen right now".
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.read<ThemeProvider>();

    final accountKey = auth.status == AuthStatus.authenticated
        ? (auth.userId?.toString() ?? auth.email)
        : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      themeProvider.updateAccountKey(accountKey);
    });

    switch (auth.status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        switch (auth.role) {
          case UserRole.seller:
            return const SellerShell();
          case UserRole.admin:
            return const AdminShell();
          case UserRole.customer:
          default:
            return const CustomerShell();
        }
    }
  }
}
