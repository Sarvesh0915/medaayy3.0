import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpService {
  // Point to the root functions directory
  static const _baseUrl = 'https://ptqsrehgftghnuhduqao.supabase.co/functions/v1';

  static const _anonKey = 'sb_publishable_s0SNO_RB0eJZ7L8RHG4Lmw_8DuNl_cc';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_anonKey',
      };

  Future<(bool, String?)> sendOtp(String phone) async {
    try {
      // This will correctly hit: .../functions/v1/otp-verify/send-otp
      final res = await http
          .post(Uri.parse('$_baseUrl/otp-verify/send-otp'), headers: _headers, body: jsonEncode({'phone': phone}))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) return (true, null);
      return (false, 'Server returned ${res.statusCode}: ${res.body}');
    } catch (e) {
      return (false, "Couldn't reach the server — check _baseUrl is deployed and reachable. ($e)");
    }
  }

  Future<(bool, String?)> verifyOtp(String phone, String code) async {
    try {
      // This will correctly hit: .../functions/v1/otp-verify/verify-otp
      final res = await http
          .post(Uri.parse('$_baseUrl/otp-verify/verify-otp'), headers: _headers, body: jsonEncode({'phone': phone, 'otp': code}))
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