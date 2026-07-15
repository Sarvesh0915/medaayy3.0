import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../services/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';

/// Reachable from Manage → Emergency settings. Edits the CURRENTLY ACTIVE
/// profile's preferences — if you're viewing your own profile it edits
/// yours, if you've switched to a linked parent's view it edits theirs.
class EmergencySettingsScreen extends StatefulWidget {
  const EmergencySettingsScreen({super.key});

  @override
  State<EmergencySettingsScreen> createState() => _EmergencySettingsScreenState();
}

class _EmergencySettingsScreenState extends State<EmergencySettingsScreen> {
  late String _language;
  late String _sosAction;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppState>().activeProfile;
    _language = profile?.language ?? 'EN';
    _sosAction = profile?.sosAction ?? 'notify_child';
  }

  Future<void> _save() async {
    final appState = context.read<AppState>();
    final profile = appState.activeProfile;
    if (profile == null) return;

    setState(() => _saving = true);
    final updated = await SupabaseService.instance.updateProfilePreferences(
      profile.id,
      language: _language,
      sosAction: _sosAction,
    );

    if (appState.owner == 'me') {
      appState.selfProfile = updated;
    } else {
      appState.parentProfile = updated;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final Profile? profile = appState.activeProfile;
    final isParent = appState.owner == 'parent';

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency & language')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Editing settings for ${profile?.fullName ?? (isParent ? 'this parent' : 'you')}',
            style: const TextStyle(color: Colors.grey, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _language,
            decoration: const InputDecoration(labelText: 'Preferred language (alarms & calls)'),
            items: LocalizationService.languageNames.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _language = v ?? 'EN'),
          ),
          if (isParent) ...[
            const SizedBox(height: 20),
            const Text('If the SOS button is pressed, MedAayu should:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
          ],
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
