import 'package:flutter/material.dart';
import 'login_screen.dart';

/// The very first screen anyone sees. Login and Register both lead to the
/// same phone+OTP flow underneath (there's no separate password/credential
/// system to split them technically) — but showing them as two distinct
/// choices here matches what people expect from an app's front door, and
/// the copy on the next screen adjusts slightly depending on which was
/// tapped. What actually happens after OTP is verified is unchanged:
/// an already-registered number goes straight to its dashboard, a new
/// number continues into "who is this for?".
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Image.asset('assets/logo.png', width: 96, height: 96)),
              const SizedBox(height: 20),
              Text(
                'MedAayu',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Medicine reminders and care, for you and your family.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen(isRegistering: false)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Log In'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen(isRegistering: true)),
                  ),
                  child: const Text('New here? Register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
