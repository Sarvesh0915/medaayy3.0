import 'package:url_launcher/url_launcher.dart';

/// Connects SOS to your separate ambulance-dispatch app.
///
/// TODO — fill these in once you confirm the details from your ambulance app:
///   1. If it supports a custom URL scheme (most reliable): replace
///      `_urlScheme` below with the real one, e.g. "myambulanceapp://sos".
///   2. If it only supports being opened (no deep link with data), set
///      `_packageName` to its real Android package name so we can at least
///      launch it via an Android intent, and pass location by having the
///      ambulance app itself request GPS permission once opened.
///   3. If it exposes an HTTP API instead (dispatch via a backend call
///      rather than opening the app), this whole class should instead call
///      that endpoint directly from Supabase's sos_events insert trigger —
///      tell me and I'll build that version instead, since it wouldn't
///      need the ambulance app open on the parent's phone at all.
class AmbulanceService {
  static const _urlScheme = 'ambulanceapp://sos'; // TODO: replace with your real scheme
  static const _packageName = 'com.example.ambulanceapp'; // TODO: replace with your real package name
  static const _playStoreFallback = 'https://play.google.com/store/apps/details?id=$_packageName';

  /// Attempts to open the ambulance app directly at its SOS entry point,
  /// passing location as query params if the app's scheme supports it.
  /// Falls back to the Play Store listing if the app isn't installed.
  static Future<bool> requestAmbulance({double? lat, double? lng}) async {
    final deepLink = Uri.parse(
      lat != null && lng != null ? '$_urlScheme?lat=$lat&lng=$lng' : _urlScheme,
    );

    if (await canLaunchUrl(deepLink)) {
      return launchUrl(deepLink, mode: LaunchMode.externalApplication);
    }

    // App likely isn't installed, or the scheme above needs correcting —
    // send the person to install it rather than silently doing nothing.
    final store = Uri.parse(_playStoreFallback);
    return launchUrl(store, mode: LaunchMode.externalApplication);
  }
}
