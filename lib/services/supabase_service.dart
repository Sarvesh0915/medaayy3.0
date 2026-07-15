import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/medicine.dart';

/// Wraps every Supabase table call the app needs. Keeping this in one place
/// means the screens never touch `Supabase.instance` directly, which makes it
/// much easier to change the schema later without hunting through every screen.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(
      url: 'https://ptqsrehgftghnuhduqao.supabase.co',
      anonKey: 'sb_publishable_s0SNO_RB0eJZ7L8RHG4Lmw_8DuNl_cc',
    );
  }

  String? get currentUserId => _client.auth.currentUser?.id;

  // ---- Profiles ----

  Future<Profile> createProfile(Profile profile, {required String ownerId}) async {
    final row = await _client
        .from('profiles')
        .insert(profile.toInsertMap(ownerId: ownerId))
        .select()
        .single();
    return Profile.fromMap(row);
  }

  /// Used for editable-anytime settings (language, emergency action) —
  /// only updates the given fields, not the whole profile.
  Future<Profile> updateProfilePreferences(
    String profileId, {
    String? language,
    String? sosAction,
  }) async {
    final updates = <String, dynamic>{};
    if (language != null) updates['language'] = language;
    if (sosAction != null) updates['sos_action'] = sosAction;

    final row = await _client.from('profiles').update(updates).eq('id', profileId).select().single();
    return Profile.fromMap(row);
  }

  Future<Profile?> getSelfProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final rows = await _client
        .from('profiles')
        .select()
        .eq('auth_user_id', uid)
        .eq('role', 'self')
        .limit(1);
    if (rows.isEmpty) return null;
    return Profile.fromMap(rows.first);
  }

  Future<Profile?> getLinkedParentProfile(String selfProfileId) async {
    final rows = await _client
        .from('profiles')
        .select()
        .eq('owner_id', selfProfileId)
        .eq('role', 'parent')
        .limit(1);
    if (rows.isEmpty) return null;
    return Profile.fromMap(rows.first);
  }

  /// Looks up a profile by phone — used right after OTP login to detect
  /// "this number already belongs to a linked parent" without any code.
  Future<Profile?> findProfileByPhone(String phone) async {
    final rows = await _client.from('profiles').select().eq('phone', phone).limit(1);
    if (rows.isEmpty) return null;
    return Profile.fromMap(rows.first);
  }

  Future<void> setPlan(String profileId, {required String planType, required String billingCycle}) async {
    await _client.from('subscriptions').insert({
      'profile_id': profileId,
      'plan_type': planType,
      'billing_cycle': billingCycle,
      'status': 'active',
    });
  }

  // ---- Medicines ----

  Future<List<Medicine>> getMedicines(String profileId) async {
    final rows = await _client
        .from('medicines')
        .select()
        .eq('profile_id', profileId)
        .order('dose_time');
    return rows.map((r) => Medicine.fromMap(r)).toList();
  }

  /// Regenerates the AI care tips for a profile based on their current
  /// medicine list, and caches the result on the profile row. Call this
  /// after a medicine is added or removed — NOT on every dashboard load,
  /// Gemini calls should track actual changes, not page views.
  Future<Profile?> refreshCareTips(String profileId) async {
    final meds = await getMedicines(profileId);
    final medicineNames = meds.map((m) => m.name).toList();

    try {
      final res = await _client.functions.invoke(
        'generate-care-tips',
        body: {'medicineNames': medicineNames},
      );
      final data = res.data as Map<String, dynamic>?;
      final tips = data?['tips'] as String?;
      if (tips == null) return null;

      final row = await _client
          .from('profiles')
          .update({'care_tips': tips, 'care_tips_updated_at': DateTime.now().toIso8601String()})
          .eq('id', profileId)
          .select()
          .single();
      return Profile.fromMap(row);
    } catch (_) {
      return null; // Non-critical — the dashboard just shows nothing new if this fails.
    }
  }

  Future<Medicine> addMedicine(Medicine med, {required String ownerId}) async {
    final row = await _client
        .from('medicines')
        .insert(med.toInsertMap(ownerId: ownerId))
        .select()
        .single();
    return Medicine.fromMap(row);
  }

  // ---- Billing ----

  /// Calls YOUR backend (Edge Function), which in turn calls the Android
  /// Publisher API with your service-account credentials — never call
  /// Google's billing verification directly from the app.
  Future<bool> verifyPurchase({required String productId, required String purchaseToken}) async {
    try {
      final res = await _client.functions.invoke(
        'verify-purchase',
        body: {'productId': productId, 'purchaseToken': purchaseToken},
      );
      final data = res.data as Map<String, dynamic>?;
      return data?['valid'] == true;
    } catch (_) {
      return false;
    }
  }

  // ---- SOS ----

  Future<void> logSosEvent({
    required String profileId,
    required String ownerId,
    double? lat,
    double? lng,
  }) async {
    await _client.from('sos_events').insert({
      'profile_id': profileId,
      'owner_id': ownerId,
      'location_lat': lat,
      'location_lng': lng,
      'status': 'sent',
    });
    // NOTE: notifying the child in real time (push notification) is handled
    // server-side — see supabase/functions/otp-verify/README for the
    // matching "on sos_events insert -> send FCM" trigger you'll want to add.
  }

  /// SMS is only ever sent here, on the emergency path — a backup channel
  /// in case the SOS phone call isn't picked up.
  Future<bool> sendEmergencySms({
    required String guardianPhone,
    required String elderName,
    double? lat,
    double? lng,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'notify-sos',
        body: {'guardianPhone': guardianPhone, 'elderName': elderName, 'lat': lat, 'lng': lng},
      );
      final data = res.data as Map<String, dynamic>?;
      return data?['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
