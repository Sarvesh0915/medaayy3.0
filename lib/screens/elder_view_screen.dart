import 'dart:async';
import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../models/medicine.dart';
import '../services/supabase_service.dart';
import '../services/fall_detection_service.dart';
import '../services/widget_service.dart';
import 'sos_screen.dart';

/// The parent's own device experience — deliberately large text, minimal
/// chrome, and a permanent SOS button. Kept visually simple on purpose:
/// this screen always uses a light, high-contrast theme regardless of the
/// app's light/dark setting, since readability matters more than preference
/// for this audience.
///
/// Fall detection also only runs here — on the parent's own device — never
/// on the child's dashboard, since it depends on THIS phone's accelerometer.
class ElderViewScreen extends StatefulWidget {
  final Profile profile;
  const ElderViewScreen({super.key, required this.profile});

  @override
  State<ElderViewScreen> createState() => _ElderViewScreenState();
}

class _ElderViewScreenState extends State<ElderViewScreen> {
  List<Medicine> _meds = [];
  final Set<String> _taken = {};

  final _fallDetector = FallDetectionService();
  bool _fallDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _load();
    // NOTE: this only detects falls while this screen is on-screen and the
    // app is in the foreground. See BUILD_INSTRUCTIONS.md for what a true
    // always-on background version additionally requires.
    _fallDetector.start(onFallDetected: _handlePossibleFall);
  }

  @override
  void dispose() {
    _fallDetector.stop();
    super.dispose();
  }

  Future<void> _load() async {
    await WidgetService.cacheElderProfile(widget.profile);
    final meds = await SupabaseService.instance.getMedicines(widget.profile.id);
    if (mounted) setState(() => _meds = meds);
  }

  void _handlePossibleFall() {
    if (_fallDialogShowing || !mounted) return;
    _fallDialogShowing = true;

    int secondsLeft = 20;
    Timer? countdown;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            countdown ??= Timer.periodic(const Duration(seconds: 1), (t) {
              secondsLeft -= 1;
              if (secondsLeft <= 0) {
                t.cancel();
                Navigator.of(dialogContext).pop();
                _fallDialogShowing = false;
                _launchSos();
              } else {
                setDialogState(() {});
              }
            });

            return AlertDialog(
              title: const Text('Are you okay?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              content: Text(
                "We think you may have fallen. Calling for help in $secondsLeft seconds unless you tell us you're okay.",
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () {
                      countdown?.cancel();
                      Navigator.of(dialogContext).pop();
                      _fallDialogShowing = false;
                    },
                    child: const Text("I'm okay", style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _launchSos() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SosScreen(profile: widget.profile, ownerId: widget.profile.ownerId ?? widget.profile.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFEFF6F1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF123A5C)),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD1382B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    icon: const Icon(Icons.warning_amber_rounded, size: 26),
                    label: const Text('SOS — Get help now', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SosScreen(
                          profile: widget.profile,
                          ownerId: widget.profile.ownerId ?? widget.profile.id,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Good morning, ${widget.profile.fullName.split(' ').first}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 15, color: Colors.teal.shade700),
                    const SizedBox(width: 5),
                    Text(
                      'Fall detection is on while this screen is open',
                      style: TextStyle(fontSize: 12, color: Colors.teal.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _meds.isEmpty
                      ? const Center(child: Text("No medicines yet.", style: TextStyle(fontSize: 16)))
                      : ListView.separated(
                          itemCount: _meds.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (_, i) {
                            final m = _meds[i];
                            final taken = _taken.contains(m.id);
                            return InkWell(
                              onTap: () => setState(() {
                                taken ? _taken.remove(m.id) : _taken.add(m.id);
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: taken ? Colors.teal.withOpacity(0.15) : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: taken ? Colors.teal : Colors.black12, width: 2),
                                ),
                                child: Row(
                                  children: [
                                    Icon(taken ? Icons.check_circle : Icons.circle_outlined, size: 30),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(m.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                                        Text(m.displayTime, style: const TextStyle(fontSize: 15)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
