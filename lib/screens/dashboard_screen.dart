import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'home_tab.dart';
import 'medications_tab.dart';
import 'manage_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final profile = appState.activeProfile;
    final displayName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : (appState.owner == 'me' ? 'You' : 'Parent');

    final tabs = [
      const HomeTab(),
      const MedicationsTab(),
      const ManageTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
            const SizedBox(width: 10),
            Text(displayName),
            if (appState.hasLinkedParent) ...[
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 18),
            ],
          ],
        ),
        actions: [
          if (appState.hasLinkedParent)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch profile',
              onPressed: () => appState.setOwner(appState.owner == 'me' ? 'parent' : 'me'),
            ),
          IconButton(
            icon: Icon(appState.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle theme',
            onPressed: appState.toggleTheme,
          ),
        ],
      ),
      body: tabs[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.medication_outlined), selectedIcon: Icon(Icons.medication), label: 'Medications'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Manage'),
        ],
      ),
    );
  }
}
