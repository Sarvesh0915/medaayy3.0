import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class OtpService {
  static const _baseUrl = 'https://bulkblaster-otp-api-ch-290441563653.asia-south1.run.app';
  static const _bulkBlasterApiKey = 'bb_isYwVOkSohuApW0p4heWYVtbzijLcaGu';

  String? _currentGeneratedOtp;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  Future<(bool, String?)> sendOtp(String phone) async {
    try {
      final formattedPhone = phone.replaceAll('+91', '').trim();

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
      // Fixed the type mismatch by casting the error payload explicitly as String?
      return (false, (data['error'] as String?) ?? 'Failed to send OTP');
    } catch (e) {
      return (false, "Connection error: $e");
    }
  }

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