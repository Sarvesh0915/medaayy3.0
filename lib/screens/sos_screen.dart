import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../services/ambulance_service.dart';

/// Always logs the event (so the child gets notified either way — see the
/// sos_events -> FCM trigger noted in otp-verify's README) and always
/// opens the dialer to the guardian. If the profile's `sosAction` is set
/// to 'ambulance', it ALSO requests the nearest ambulance via
/// AmbulanceService — that's an addition on top of notifying the child,
/// not a replacement for it.
///
/// Takes the profile directly (rather than reading it from AppState) so it
/// works both from the child's dashboard AND from the elder's own device,
/// which doesn't use AppState at all.
class SosScreen extends StatefulWidget {
  final Profile profile;
  final String ownerId;

  const SosScreen({super.key, required this.profile, required this.ownerId});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _sent = false;
  bool _ambulanceRequested = false;
  bool _smsSent = false;

  @override
  void initState() {
    super.initState();
    _trigger();
  }

  Future<void> _trigger() async {
    double? lat, lng;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {
      // Location is best-effort — SOS still proceeds without it.
    }

    await SupabaseService.instance.logSosEvent(
      profileId: widget.profile.id,
      ownerId: widget.ownerId,
      lat: lat,
      lng: lng,
    );

    final guardianPhone = widget.profile.sosContactPhone;
    if (guardianPhone != null && guardianPhone.isNotEmpty) {
      await launchUrl(Uri.parse('tel:$guardianPhone'));

      // Backup channel: SMS doesn't depend on someone picking up live, so
      // it goes out regardless of whether the call connects. This is the
      // only place in the app that sends an SMS — never for routine
      // reminders, only this emergency path.
      final smsOk = await SupabaseService.instance.sendEmergencySms(
        guardianPhone: guardianPhone,
        elderName: widget.profile.fullName,
        lat: lat,
        lng: lng,
      );
      if (mounted) setState(() => _smsSent = smsOk);
    }

    if (widget.profile.sosAction == 'ambulance') {
      final ok = await AmbulanceService.requestAmbulance(lat: lat, lng: lng);
      if (mounted) setState(() => _ambulanceRequested = ok);
    }

    if (mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A0E0B),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_in_talk, color: Colors.white, size: 60),
              const SizedBox(height: 20),
              Text(
                _sent ? 'Alert sent' : 'Calling for help…',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "The guardian's phone dialer has opened and their location was logged."
                "${_sent && _smsSent ? ' A backup SMS was also sent.' : ''}"
                "${_sent && _ambulanceRequested ? ' An ambulance was requested.' : ''}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
