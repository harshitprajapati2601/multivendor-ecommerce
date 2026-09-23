import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? email;

  const ForgotPasswordScreen({super.key, this.email});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _codeSent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestResetCode() async {
    if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.requestPasswordReset(_emailController.text.trim());
    if (!mounted) return;

    if (ok) {
      setState(() => _codeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset code sent to your email.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Could not send reset code')),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.resetPassword(
      email: _emailController.text.trim(),
      otp: _otpController.text.trim(),
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (ok) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Password Reset Successful'),
          content: const Text('Your password has been changed. You can now log in with your new password.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Pop ForgotPasswordScreen back to LoginScreen
              },
              child: const Text('Log In'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Failed to reset password. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Icon(Icons.lock_reset_rounded, size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              _codeSent ? 'Reset Your Password' : 'Forgot Your Password?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _codeSent
                  ? 'Enter the code sent to ${_emailController.text.trim()} along with your new password.'
                  : 'Enter your email address and we will send you a verification code to reset your password.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              enabled: !_codeSent,
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            if (_codeSent) ...[
              const SizedBox(height: 16),
              AppTextField(
                controller: _otpController,
                label: 'Verification Code (OTP)',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.pin_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter verification code' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _newPasswordController,
                label: 'New Password',
                obscure: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (v) => (v == null || v.length < 8) ? 'Password must be at least 8 characters' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
                obscure: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (v) => (v == null || v.isEmpty) ? 'Confirm your new password' : null,
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: _codeSent ? 'Reset Password' : 'Send Reset Code',
              isLoading: auth.isLoading,
              onPressed: _codeSent ? _resetPassword : _requestResetCode,
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: auth.isLoading ? null : _requestResetCode,
                    child: const Text('Resend code'),
                  ),
                  const Text(' • '),
                  TextButton(
                    onPressed: () => setState(() => _codeSent = false),
                    child: const Text('Change email'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
