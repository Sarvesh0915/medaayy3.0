import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpService {
  static const _baseUrl = 'https://bulkblaster-otp-api-ch-290441563653.asia-south1.run.app';
  static const _bulkBlasterApiKey = 'bb_isYwVOkSohuApW0p4heWYVtbzijLcaGu';

  // Static variable ensures the generated OTP persists across screens/instances
  static String? _currentGeneratedOtp;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  /// Generates a dynamic 6-digit OTP and dispatches it through the Bulk Blaster gateway
  Future<(bool, String?)> sendOtp(String phone) async {
    try {
      final formattedPhone = phone.replaceAll('+91', '').trim();

      // Generates an independent, non-static 6-digit verification pin sequence
      final random = Random();
      _currentGeneratedOtp = (100000 + random.nextInt(900000)).toString();

      final res = await http.post(
        Uri.parse('$_baseUrl/send-otp'),
        headers: _headers,
        body: jsonEncode({
          'apiKey': _bulkBlasterApiKey,
          'phone': formattedPhone,
          'otp': _currentGeneratedOtp, 
          'brandName': 'Medaayu'
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return (true, null);
      }
      return (false, (data['error'] as String?) ?? 'Failed to send OTP');
    } catch (e) {
      return (false, "Connection error: $e");
    }
  }

  /// Evaluates the user input against the live generated security code string and provisions a Supabase user
  /// Evaluates the user input against the live generated security code string and provisions a Supabase user session
  Future<(bool, String?)> verifyOtp(String phone, String code) async {
    try {
      if (_currentGeneratedOtp != null && code == _currentGeneratedOtp) {
        // Authenticates an anonymous session to prevent backend client queries from hanging
        final client = Supabase.instance.client;
        if (client.auth.currentSession == null) {
          await client.auth.signInAnonymously();
        }
        return (true, null);
      }
      return (false, 'Invalid verification code');
    } catch (e) {
      return (false, "Verification failed: $e");
    }
  }