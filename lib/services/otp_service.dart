import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// IMPORTANT: this calls YOUR backend, not Bulk Blaster or Supabase directly.
class OtpService {
  // Base URL pointing directly to your deployed Edge Function route
  static const _baseUrl = 'https://ptqsrehgftghnuhduqao.supabase.co/functions/v1/otp-verify';

  static const _anonKey = 'sb_publishable_s0SNO_RB0eJZ7L8RHG4Lmw_8DuNl_cc';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_anonKey',
      };

  /// Returns (success, errorMessage) instead of throwing.
  Future<(bool, String?)> sendOtp(String phone) async {
    try {
      // Removed the trailing '/send-otp' so it hits your main function route directly
      final res = await http
          .post(Uri.parse(_baseUrl), headers: _headers, body: jsonEncode({'phone': phone}))
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
      // Removed the trailing '/verify-otp' so it hits your main function route directly
      final res = await http
          .post(Uri.parse(_baseUrl), headers: _headers, body: jsonEncode({'phone': phone, 'otp': code}))
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