import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_state.dart';
import 'welcome_screen.dart';
import 'role_select_screen.dart';
import 'emergency_settings_screen.dart';

class ManageTab extends StatelessWidget {
  const ManageTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final profile = appState.activeProfile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.workspace_premium),
            title: const Text('MedAayu Subscription'),
            subtitle: Text(
              profile?.planType != null
                  ? '${profile!.planType == 'call' ? 'Call' : 'Alarm'} plan · ${profile.billingCycle ?? ''}'
                  : 'No plan yet',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Family & Sharing'),
            subtitle: Text(
              appState.hasLinkedParent
                  ? 'Linked with ${appState.parentProfile!.fullName} · tap to switch view'
                  : 'Add a parent to this account',
            ),
            onTap: () {
              if (appState.hasLinkedParent) {
                appState.setOwner(appState.owner == 'me' ? 'parent' : 'me');
              } else {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleSelectScreen()));
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        const Text('SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Emergency & language'),
                subtitle: const Text('Reminder language, and what SOS does'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EmergencySettingsScreen()),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Dark theme'),
                value: appState.themeMode == ThemeMode.dark,
                onChanged: (_) => appState.toggleTheme(),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Log out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  appState.reset();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Center(child: Text('MedAayu prototype · v0.1', style: TextStyle(fontSize: 11, color: Colors.grey))),
      ],
    );
  }
}
