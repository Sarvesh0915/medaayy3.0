import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../services/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'dashboard_screen.dart';

class ProfileInfoScreen extends StatefulWidget {
  final String owner;
  final String planType;
  final String billingCycle;

  const ProfileInfoScreen({
    super.key,
    required this.owner,
    required this.planType,
    required this.billingCycle,
  });

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _phone = TextEditingController();
  final _sosPhone = TextEditingController();
  String? _gender;
  String? _blood;
  String _language = 'EN';
  String _sosAction = 'notify_child';
  bool _saving = false;

  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  bool get _needsPhone => widget.owner == 'parent' || widget.planType == 'call';
  bool get _needsSosPhone => widget.owner == 'parent' && widget.planType == 'call';
  bool get _isParent => widget.owner == 'parent';

  String get _phoneLabel {
    if (widget.owner == 'me') return "Phone number (we'll call this)";
    return widget.planType == 'call'
        ? 'Phone number (for reminder calls)'
        : "Parent's phone number (for their login)";
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final appState = context.read<AppState>();

    // For "myself" the profile is owned by the just-created auth user; for a
    // parent, it's owned by the self profile (the child's account).
    final ownerId = widget.owner == 'me'
        ? SupabaseService.instance.currentUserId!
        : appState.selfProfile!.id;

    final profile = Profile(
      id: '', // assigned by Supabase on insert
      role: widget.owner == 'me' ? 'self' : 'parent',
      fullName: _name.text.trim(),
      age: _age.text.trim(),
      gender: _gender,
      bloodGroup: _blood,
      phone: _needsPhone ? _phone.text.trim() : null,
      sosContactPhone: _needsSosPhone ? _sosPhone.text.trim() : null,
      language: _language,
      sosAction: _sosAction,
    );

    final saved = await SupabaseService.instance.createProfile(profile, ownerId: ownerId);
    await SupabaseService.instance.setPlan(saved.id, planType: widget.planType, billingCycle: widget.billingCycle);

    if (widget.owner == 'me') {
      appState.selfProfile = saved;
    } else {
      appState.parentProfile = saved;
    }

    if (!mounted) return;
    setState(() => _saving = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.owner == 'me' ? 'A little about you' : 'A little about them')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Full name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _age,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: const ['Male', 'Female', 'Other']
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _blood,
            decoration: const InputDecoration(labelText: 'Blood group'),
            items: _bloodGroups.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: (v) => setState(() => _blood = v),
          ),
          if (_needsPhone) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(labelText: _phoneLabel, counterText: ''),
            ),
          ],
          if (_needsSosPhone) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _sosPhone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(labelText: 'Phone number for emergency SOS', counterText: ''),
            ),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _language,
            decoration: const InputDecoration(labelText: 'Preferred language (alarms & calls)'),
            items: LocalizationService.languageNames.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _language = v ?? 'EN'),
          ),
          if (_isParent) ...[
            const SizedBox(height: 18),
            const Text('If the SOS button is pressed, MedAayu should:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            const SizedBox(height: 8),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'notify_child',
              groupValue: _sosAction,
              title: const Text('Only notify me (the child)'),
              subtitle: const Text('Opens the dialer to call you directly'),
              onChanged: (v) => setState(() => _sosAction = v!),
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'ambulance',
              groupValue: _sosAction,
              title: const Text('Call the nearest ambulance'),
              subtitle: const Text('Also notifies you, and requests an ambulance'),
              onChanged: (v) => setState(() => _sosAction = v!),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('You can change this anytime in Manage → Emergency settings.', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
            ),
          ],
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _name.text.trim().isNotEmpty && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
