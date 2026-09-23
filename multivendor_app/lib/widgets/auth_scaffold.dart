import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Wraps auth-flow content (login, register, verify email, OTP login) in a
/// centered card on a soft tinted background — the classic "auth card"
/// layout instead of a full-bleed form pinned to the top-left.
///
/// Vertically centers when the content is short enough to fit the screen,
/// and scrolls naturally when it isn't (e.g. the register form, or a small
/// phone with the keyboard open).
class AuthScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget child;
  final double maxWidth;

  const AuthScaffold({
    super.key,
    this.appBar,
    required this.child,
    this.maxWidth = 440,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: appBar,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1E1E38), theme.scaffoldBackgroundColor]
                : [const Color(0xFFEEF0FE), theme.scaffoldBackgroundColor],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.dividerColor),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : AppColors.primary.withValues(alpha: 0.06),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

}

/// The circular brand mark used at the top of every auth card.
class AuthLogo extends StatelessWidget {
  final double size;
  const AuthLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(Icons.storefront_rounded, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}
