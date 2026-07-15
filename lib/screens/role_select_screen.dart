import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'plan_select_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('MedAayu'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Who are we setting this up for?', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            _RoleCard(
              icon: Icons.person,
              color: Theme.of(context).colorScheme.primary,
              title: 'Myself',
              subtitle: 'Track your own medicines and reminders',
              onTap: () {
                appState.setOwner('me');
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlanSelectScreen(owner: 'me')),
                );
              },
            ),
            const SizedBox(height: 12),
            _RoleCard(
              icon: Icons.favorite,
              color: Theme.of(context).colorScheme.error,
              title: 'A parent',
              subtitle: 'Set up and manage reminders for someone you care for',
              onTap: () {
                appState.setOwner('parent');
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlanSelectScreen(owner: 'parent')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
