import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../models/profile.dart';

/// Caches the elder's own profile locally so a home screen widget tap can
/// jump straight to the SOS screen from a cold start, without needing a
/// fresh login or network round trip first — speed matters more than
/// freshness for an emergency button.
class WidgetService {
  static const _cacheKey = 'medaayu_elder_profile_cache';

  static Future<void> cacheElderProfile(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode({
        'id': profile.id,
        'owner_id': profile.ownerId,
        'full_name': profile.fullName,
        'sos_contact_phone': profile.sosContactPhone,
        'sos_action': profile.sosAction,
        'language': profile.language,
      }),
    );
  }

  static Future<Profile?> getCachedElderProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return Profile(
      id: map['id'],
      ownerId: map['owner_id'],
      role: 'parent',
      fullName: map['full_name'] ?? '',
      sosContactPhone: map['sos_contact_phone'],
      sosAction: map['sos_action'] ?? 'notify_child',
      language: map['language'] ?? 'EN',
    );
  }

  /// Call once at app startup. Returns true if the app was opened by a tap
  /// on the SOS widget (vs a normal launch) — main.dart uses this to
  /// decide whether to skip straight to the SOS screen.
  static Future<bool> launchedFromSosWidget() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    return uri?.host == 'sos';
  }

  /// Listens for widget taps while the app is already running/backgrounded.
  static void listenForWidgetTaps(void Function() onSosTapped) {
    HomeWidget.widgetClicked.listen((uri) {
      if (uri?.host == 'sos') onSosTapped();
    });
  }
}
