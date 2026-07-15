import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// IMPORTANT: this calls YOUR backend, not Bulk Blaster or Supabase directly.
///
/// Why: Bulk Blaster sends the OTP, but only YOUR backend should hold the
/// Bulk Blaster API key and the Supabase *service role* key — neither of
/// those can ever ship inside the app. Your backend's job on each call is:
///   POST /send-otp   -> generates a code, calls Bulk Blaster /send-otp, stores the code
///   POST /verify-otp -> checks the code, then creates/finds the Supabase auth
///                       user for this phone and returns a Supabase session
///                       (access_token + refresh_token) to the app.
///
/// See supabase/functions/otp-verify/README.md in this project for a
/// ready-to-deploy Supabase Edge Function that does exactly this.
///
/// TWO THINGS THAT COMMONLY CAUSE "OTP never arrives" / a stuck spinner:
///   1. `_baseUrl` below is still the placeholder — it needs to be your
///      actual deployed Edge Function URL, something like:
///      https://ptqsrehgftghnuhduqao.supabase.co/functions/v1/otp-verify
///   2. Supabase Edge Functions reject requests with no valid auth header
///      by DEFAULT (401), even before your function code runs — this file
///      now sends the Supabase anon key as a Bearer token to satisfy that,
///      which is safe (the anon key is meant to be public), but you can
///      also deploy with `--no-verify-jwt` to skip this requirement
///      entirely for a pre-login endpoint like this one.
class OtpService {
  // TODO: replace with your deployed Edge Function base URL (see note above).
  static const _baseUrl = 'https://YOUR-PROJECT.supabase.co/functions/v1/otp-verify';

  static const _anonKey = 'sb_publishable_s0SNO_RB0eJZ7L8RHG4Lmw_8DuNl_cc';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_anonKey',
      };

  /// Returns (success, errorMessage) instead of throwing, so the UI can
  /// always show something instead of spinning forever on a network failure.
  Future<(bool, String?)> sendOtp(String phone) async {
    try {
      final res = await http
          .post(Uri.parse('$_baseUrl/send-otp'), headers: _headers, body: jsonEncode({'phone': phone}))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) return (true, null);
      return (false, 'Server returned ${res.statusCode}: ${res.body}');
    } catch (e) {
      return (false, "Couldn't reach the server — check _baseUrl is deployed and reachable. ($e)");
    }
  }

  /// Returns (success, errorMessage). Sets the Supabase session on success.
  Future<(bool, String?)> verifyOtp(String phone, String code) async {
    try {
      final res = await http
          .post(Uri.parse('$_baseUrl/verify-otp'), headers: _headers, body: jsonEncode({'phone': phone, 'otp': code}))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return (false, 'Server returned ${res.statusCode}: ${res.body}');

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      if (accessToken == null || refreshToken == null) {
        return (false, 'Server did not return a session — check the Edge Function logs.');
      }

      await Supabase.instance.client.auth.setSession(refreshToken);
      return (true, null);
    } catch (e) {
      return (false, "Couldn't reach the server. ($e)");
    }
  }
}
