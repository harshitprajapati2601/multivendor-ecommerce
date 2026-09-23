import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/primary_button.dart';

class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email')));
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.requestLoginOtp(_emailController.text.trim());
    if (!mounted) return;
    if (ok) {
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code sent to your email.')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Could not send code')));
    }
  }

  Future<void> _verifyOtp() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyLoginOtp(email: _emailController.text.trim(), otp: _otpController.text.trim());
    if (!mounted) return;
    if (ok) {
      // AuthProvider flipped to authenticated and RootShell rebuilt the
      // shell underneath — but this screen was reached via Navigator.push,
      // so it's still on top of it. Pop back to the root route to reveal it.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Could not complete sign-in. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      appBar: AppBar(
        title: const Text('Log in with a code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: Icon(Icons.sms_outlined, size: 52, color: AppColors.primary)),
          const SizedBox(height: 16),
          Text(
            _otpSent ? 'Enter your code' : 'Passwordless login',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _otpSent
                ? 'We emailed a one-time code to ${_emailController.text.trim()}.'
                : "We'll email you a one-time code — no password needed.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _emailController,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
          ),
          if (_otpSent) ...[
            const SizedBox(height: 16),
            AppTextField(
              controller: _otpController,
              label: 'One-time code',
              keyboardType: TextInputType.number,
              prefixIcon: Icons.pin_outlined,
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: _otpSent ? 'Verify & log in' : 'Send code',
            isLoading: auth.isLoading,
            onPressed: _otpSent ? _verifyOtp : _requestOtp,
          ),
          if (_otpSent) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: auth.isLoading ? null : _requestOtp,
                child: const Text('Resend code'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
