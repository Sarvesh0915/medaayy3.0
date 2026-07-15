class Profile {
  final String id;
  final String? ownerId;
  final String role; // 'self' or 'parent'
  final String fullName;
  final String? age;
  final String? gender;
  final String? bloodGroup;
  final String? phone;
  final String? sosContactPhone;
  final String? planType; // 'alarm' or 'call'
  final String? billingCycle; // 'monthly' or 'yearly'
  final String language; // Bulk Blaster language code: EN, HI, TE, TA, KN, ML, BN, GU, MR, PA
  final String sosAction; // 'ambulance' or 'notify_child'
  final String? careTips; // AI-generated, cached — see generate-care-tips function
  final DateTime? careTipsUpdatedAt;

  Profile({
    required this.id,
    this.ownerId,
    required this.role,
    required this.fullName,
    this.age,
    this.gender,
    this.bloodGroup,
    this.phone,
    this.sosContactPhone,
    this.planType,
    this.billingCycle,
    this.language = 'EN',
    this.sosAction = 'notify_child',
    this.careTips,
    this.careTipsUpdatedAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        ownerId: map['owner_id'] as String?,
        role: map['role'] as String? ?? 'self',
        fullName: map['full_name'] as String? ?? '',
        age: map['age']?.toString(),
        gender: map['gender'] as String?,
        bloodGroup: map['blood_group'] as String?,
        phone: map['phone'] as String?,
        sosContactPhone: map['sos_contact_phone'] as String?,
        planType: map['plan_type'] as String?,
        billingCycle: map['billing_cycle'] as String?,
        language: map['language'] as String? ?? 'EN',
        sosAction: map['sos_action'] as String? ?? 'notify_child',
        careTips: map['care_tips'] as String?,
        careTipsUpdatedAt: map['care_tips_updated_at'] != null ? DateTime.tryParse(map['care_tips_updated_at']) : null,
      );

  Map<String, dynamic> toInsertMap({required String ownerId}) => {
        'role': role,
        'owner_id': ownerId,
        'full_name': fullName,
        'age': int.tryParse(age ?? ''),
        'gender': gender,
        'blood_group': bloodGroup,
        'phone': phone,
        'sos_contact_phone': sosContactPhone,
        'language': language,
        'sos_action': sosAction,
      };

  Profile copyWith({String? language, String? sosAction, String? careTips, DateTime? careTipsUpdatedAt}) => Profile(
        id: id,
        ownerId: ownerId,
        role: role,
        fullName: fullName,
        age: age,
        gender: gender,
        bloodGroup: bloodGroup,
        phone: phone,
        sosContactPhone: sosContactPhone,
        planType: planType,
        billingCycle: billingCycle,
        language: language ?? this.language,
        sosAction: sosAction ?? this.sosAction,
        careTips: careTips ?? this.careTips,
        careTipsUpdatedAt: careTipsUpdatedAt ?? this.careTipsUpdatedAt,
      );
}
