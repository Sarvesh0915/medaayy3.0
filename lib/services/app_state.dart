import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../models/medicine.dart';
import '../services/supabase_service.dart';

class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light; // MedAayu defaults to light

  Profile? selfProfile;
  Profile? parentProfile;
  String owner = 'me'; // 'me' or 'parent' — which profile is being viewed

  List<Medicine> meMedicines = [];
  List<Medicine> parentMedicines = [];

  Profile? get activeProfile => owner == 'me' ? selfProfile : parentProfile;
  List<Medicine> get activeMedicines => owner == 'me' ? meMedicines : parentMedicines;
  bool get hasLinkedParent => parentProfile != null;

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setOwner(String value) {
    owner = value;
    notifyListeners();
  }

  Future<void> loadSelfProfile() async {
    selfProfile = await SupabaseService.instance.getSelfProfile();
    if (selfProfile != null) {
      meMedicines = await SupabaseService.instance.getMedicines(selfProfile!.id);
      parentProfile = await SupabaseService.instance.getLinkedParentProfile(selfProfile!.id);
      if (parentProfile != null) {
        parentMedicines = await SupabaseService.instance.getMedicines(parentProfile!.id);
      }
    }
    notifyListeners();
  }

  Future<void> refreshActiveMedicines() async {
    final profile = activeProfile;
    if (profile == null) return;
    final meds = await SupabaseService.instance.getMedicines(profile.id);
    if (owner == 'me') {
      meMedicines = meds;
    } else {
      parentMedicines = meds;
    }
    notifyListeners();
  }

  Future<void> refreshCareTips() async {
    final profile = activeProfile;
    if (profile == null) return;
    final updated = await SupabaseService.instance.refreshCareTips(profile.id);
    if (updated == null) return;
    if (owner == 'me') {
      selfProfile = updated;
    } else {
      parentProfile = updated;
    }
    notifyListeners();
  }

  void reset() {
    selfProfile = null;
    parentProfile = null;
    owner = 'me';
    meMedicines = [];
    parentMedicines = [];
    notifyListeners();
  }
}
