import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'services/billing_service.dart';
import 'services/widget_service.dart';
import 'services/app_state.dart';
import 'screens/welcome_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/sos_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must init before Crashlytics can catch anything.
  try {
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }

  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }

  try {
    await BillingService.instance.init(); 
  } catch (e) {
    debugPrint('Billing init failed: $e');
  }

  bool launchedFromSos = false;
  try {
    launchedFromSos = await WidgetService.launchedFromSosWidget();
  } catch (e) {
    debugPrint('Widget check failed: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MedAayuApp(launchedFromSosWidget: launchedFromSos),
    ),
  );
}

class MedAayuApp extends StatelessWidget {
  final bool launchedFromSosWidget;
  const MedAayuApp({super.key, this.launchedFromSosWidget = false});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MaterialApp(
      title: 'MedAayu',
      debugShowCheckedModeBanner: false,
      themeMode: appState.themeMode,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: launchedFromSosWidget ? const _SosWidgetEntry() : (appState.selfProfile == null ? const WelcomeScreen() : const DashboardScreen()),
    );
  }
}

/// Loads the cached elder profile (saved the last time they used the app
/// normally) and jumps straight into SOS — no login screen in the way
/// when someone actually needs help.
class _SosWidgetEntry extends StatelessWidget {
  const _SosWidgetEntry();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: WidgetService.getCachedElderProfile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final profile = snapshot.data;
        if (profile == null) {
          // Widget was tapped but no one has logged in on this device yet.
          return const WelcomeScreen();
        }
        return SosScreen(profile: profile, ownerId: profile.ownerId ?? profile.id);
      },
    );
  }
}
