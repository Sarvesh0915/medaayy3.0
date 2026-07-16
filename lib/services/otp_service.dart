import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpService {
  // Updated direct Bulk Blaster API Endpoint containing the new '-ch-' routing sub-domain
  static const _baseUrl = 'https://bulkblaster-otp-api-ch-290441563653.asia-south1.run.app';
  static const _bulkBlasterApiKey = 'bb_isYwVOkSohuApW0p4heWYVtbzijLcaGu';

  // Holds the dynamically generated OTP in volatile memory for validation checks
  String? _currentGeneratedOtp;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  /// Generates a dynamic 6-digit OTP and dispatches it through the updated Bulk Blaster gateway
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
      return (false, data['error'] ?? 'Failed to send OTP');
    } catch (e) {
      return (false, "Connection error: $e");
    }
  }

  /// Evaluates the user input against the live generated security code string
  Future<(bool, String?)> verifyOtp(String phone, String code) async {
    try {
      if (_currentGeneratedOtp != null && code == _currentGeneratedOtp) {
        return (true, null);
      }
      return (false, 'Invalid verification code');
    } catch (e) {
      return (false, "Verification failed: $e");
    }
  }
}