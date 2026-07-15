class Medicine {
  final String id;
  final String profileId;
  final String name;
  final String? form;
  final String? frequency;
  final String? doseTime; // "HH:mm"
  final int? pillsLeft;
  final String? foodInstruction;

  Medicine({
    required this.id,
    required this.profileId,
    required this.name,
    this.form,
    this.frequency,
    this.doseTime,
    this.pillsLeft,
    this.foodInstruction,
  });

  factory Medicine.fromMap(Map<String, dynamic> map) => Medicine(
        id: map['id'] as String,
        profileId: map['profile_id'] as String,
        name: map['name'] as String? ?? 'Medicine',
        form: map['form'] as String?,
        frequency: map['frequency'] as String?,
        doseTime: map['dose_time'] as String?,
        pillsLeft: map['pills_left'] as int?,
        foodInstruction: map['food_instruction'] as String?,
      );

  Map<String, dynamic> toInsertMap({required String ownerId}) => {
        'profile_id': profileId,
        'owner_id': ownerId,
        'name': name,
        'form': form,
        'frequency': frequency,
        'dose_time': doseTime,
        'pills_left': pillsLeft,
        'food_instruction': foodInstruction,
      };

  /// "8:00 AM" style display, converted from stored 24h "HH:mm".
  String get displayTime {
    final raw = doseTime;
    if (raw == null || !raw.contains(':')) return '—';
    final parts = raw.split(':');
    final h24 = int.tryParse(parts[0]) ?? 0;
    final min = parts[1].padLeft(2, '0');
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    final h12 = (h24 % 12 == 0) ? 12 : h24 % 12;
    return '$h12:$min $ampm';
  }
}
