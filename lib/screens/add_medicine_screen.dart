import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medicine.dart';
import '../services/app_state.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import 'scan_screen.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _name = TextEditingController();
  String? _form;
  String? _frequency;
  String? _food;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  final _pillsLeft = TextEditingController(text: '30');
  bool _saving = false;

  static const _forms = ['Pill', 'Injection', 'Solution (liquid)', 'Drops', 'Inhaler', 'Powder', 'Other'];
  static const _frequencies = ['Once a day', 'Twice a day', '3 times a day', 'More than 3 times a day', 'Only as needed'];
  static const _foods = ['Before eating', 'While eating', 'After eating', "Doesn't matter"];

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  String get _time24 =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final profile = appState.activeProfile!;
    final ownerId = appState.selfProfile!.id;

    final med = Medicine(
      id: '',
      profileId: profile.id,
      name: _name.text.trim().isEmpty ? 'Medicine' : _name.text.trim(),
      form: _form,
      frequency: _frequency,
      doseTime: _time24,
      pillsLeft: int.tryParse(_pillsLeft.text) ?? 0,
      foodInstruction: _food,
    );

    final saved = await SupabaseService.instance.addMedicine(med, ownerId: ownerId);

    // Only alarm-plan medicines get the on-device alarm; call-plan reminders
    // are triggered server-side via Bulk Blaster instead.
    if (profile.planType == 'alarm') {
      await NotificationService.instance.scheduleDailyAlarm(
        id: saved.id.hashCode,
        medicineName: saved.name,
        time: _time24,
        languageCode: profile.language,
      );
    }

    await appState.refreshActiveMedicines();

    // Fire-and-forget: don't make the person wait on Gemini to finish
    // saving their medicine. The Home tab will pick up the new tips next
    // time it rebuilds (see AppState.refreshCareTips).
    unawaited(appState.refreshCareTips());

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  Future<void> _scanInstead() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _name.text = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a medicine')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan a prescription instead'),
            onPressed: _scanInstead,
          ),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Medicine name')),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _form,
            decoration: const InputDecoration(labelText: 'Form'),
            items: _forms.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => _form = v),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _frequency,
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => _frequency = v),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Time of dose'),
            trailing: Text(_time.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: _pickTime,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pillsLeft,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Pills left'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _food,
            decoration: const InputDecoration(labelText: 'With food'),
            items: _foods.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => _food = v),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
