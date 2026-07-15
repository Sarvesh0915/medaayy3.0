import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/otp_service.dart';
import '../services/supabase_service.dart';
import '../services/app_state.dart';
import 'role_select_screen.dart';
import 'dashboard_screen.dart';
import 'elder_view_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  final _otpService = OtpService();
  bool _verifying = false;
  String? _error;

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _error = null;
    });

    final (ok, error) = await _otpService.verifyOtp(widget.phone, _codeController.text.trim());
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _verifying = false;
        _error = error ?? "That code isn't right. Try again.";
      });
      return;
    }

    // A phone number that already belongs to a linked parent skips straight
    // to their simplified view — no code needed, the number is enough.
    final existing = await SupabaseService.instance.findProfileByPhone(widget.phone);
    if (!mounted) return;

    if (existing != null && existing.role == 'parent') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ElderViewScreen(profile: existing)),
        (route) => false,
      );
      return;
    }

    final appState = context.read<AppState>();
    await appState.loadSelfProfile();
    if (!mounted) return;

    setState(() => _verifying = false);

    if (appState.selfProfile != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter the code')),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: 'We sent a 6-digit code to ',
                children: [TextSpan(text: '+91 ${widget.phone}', style: const TextStyle(fontWeight: FontWeight.bold))],
              ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _codeController.text.trim().length == 6 && !_verifying ? _verify : null,
                child: _verifying
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verify & continue'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _otpService.sendOtp(widget.phone),
              child: const Text('Resend code'),
            ),
          ],
        ),
      ),
    );
  }
}
