import 'package:flutter/material.dart';
import '../services/otp_service.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isRegistering;
  const LoginScreen({super.key, this.isRegistering = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpService = OtpService();
  bool _sending = false;

  bool get _isValid => _phoneController.text.trim().length == 10;

  Future<void> _sendOtp() async {
    setState(() => _sending = true);
    final phone = _phoneController.text.trim();
    final (ok, error) = await _otpService.sendOtp(phone);
    setState(() => _sending = false);

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? "Couldn't send the code. Please try again."), duration: const Duration(seconds: 6)),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OtpScreen(phone: phone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Image.asset('assets/logo.png', width: 72, height: 72),
              const SizedBox(height: 16),
              Text(
                widget.isRegistering ? "Let's get you registered" : 'Welcome back',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text("We'll text a 6-digit code to confirm it's you."),
              const SizedBox(height: 24),
              const Text('Mobile number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('+91', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: const InputDecoration(counterText: '', hintText: '98765 43210'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isValid && !_sending ? _sendOtp : null,
                  child: _sending
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send OTP'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
