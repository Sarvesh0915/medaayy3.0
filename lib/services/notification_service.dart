import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'localization_service.dart';

/// This is the ₹99 "alarm reminder" tier, built the same way a real alarm
/// clock app works: an exact daily notification on Android's alarm channel,
/// not the regular notification channel, so it can still make sound even
/// when the phone is on silent (silent mode mutes the ringer/notification
/// stream, not STREAM_ALARM).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    const androidChannel = AndroidNotificationChannel(
      'medaayu_alarm_channel',
      'Medicine alarms',
      description: 'Loud, repeating alarms for medicine reminders',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm_sound'), // add res/raw/alarm_sound.mp3
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Schedules a daily repeating alarm for one medicine dose.
  /// `time` is 24h "HH:mm", e.g. "08:00". `languageCode` is the profile's
  /// chosen language (set at registration, editable anytime in Settings) —
  /// same code Bulk Blaster uses for the call tier, so alarm text and call
  /// speech always match what the person actually chose.
  Future<void> scheduleDailyAlarm({
    required int id,
    required String medicineName,
    required String time,
    String languageCode = 'EN',
  }) async {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    final scheduled = _nextInstanceOf(hour, minute);
    final title = LocalizationService.alarmTitle(languageCode, medicineName);
    final body = LocalizationService.alarmBody(languageCode);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medaayu_alarm_channel',
          'Medicine alarms',
          channelDescription: 'Loud, repeating alarms for medicine reminders',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true, // shows over the lock screen like a real alarm
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(sound: 'alarm_sound.aiff', presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily at this time
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAlarm(int id) => _plugin.cancel(id);

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
