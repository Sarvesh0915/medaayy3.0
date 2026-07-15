import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'add_medicine_screen.dart';

class MedicationsTab extends StatelessWidget {
  const MedicationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final meds = appState.activeMedicines;

    return RefreshIndicator(
      onRefresh: appState.refreshActiveMedicines,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
        children: [
          Text('Active meds', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (meds.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('No medicines added yet.')),
            )
          else
            ...meds.map((m) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.medication),
                    title: Text('${m.name}${m.form != null ? ' · ${m.form}' : ''}'),
                    subtitle: Text(
                      'Next reminder: ${m.displayTime}'
                      '${m.pillsLeft != null ? '  ·  ${m.pillsLeft} pill(s) left' : ''}',
                      style: TextStyle(
                        color: (m.pillsLeft ?? 99) <= 5 ? Theme.of(context).colorScheme.error : null,
                        fontWeight: (m.pillsLeft ?? 99) <= 5 ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add a med'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
