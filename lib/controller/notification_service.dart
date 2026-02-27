import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:hive/hive.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// Initialize notification plugin & timezone
  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings =
    InitializationSettings(android: androidInit, iOS: iosInit);
    await _notificationsPlugin.initialize(initSettings);
  }

  /// Core schedule helper (works with v19.4.2)
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    bool repeatYearly = false,
  }) async {
    // If Android and exact alarm permission needed -> try to prompt user to enable
    if (Platform.isAndroid) {
      final sdkInt = await _androidSdkInt();
      if (sdkInt >= 31) {
        final granted = await Permission.scheduleExactAlarm.isGranted;
        if (!granted) {
          // open app settings for the user to enable; cannot programmatically request
          // SCHEDULE_EXACT_ALARM on older plugin versions
          await openAppSettings();
        }
      }
    }

    final androidDetails = AndroidNotificationDetails(
      'holidays_channel',
      'Holiday Notifications',
      channelDescription: 'Notifications for holidays',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    if (repeatYearly) {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } else {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  /// Cancel specific ids
  static Future<void> cancelNotifications(List<int> ids) async {
    for (final id in ids) {
      await _notificationsPlugin.cancel(id);
    }
  }

  /// Cancel all notifications (careful: clears user reminders too)
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Helper to create stable notification id for a holiday date string
  /// (ensures unique and consistent ids across app restarts)
  static int holidayNotificationId(String dateString) {
    // use a base to avoid collision with user-generated reminders
    const base = 1000000;
    final h = dateString.hashCode;
    final positive = h & 0x7fffffff;
    return base + (positive % 1000000);
  }

  /// Schedule list of holidays to notify according to user settings.
  /// - holidays: list of maps with keys 'date' (yyyy-mm-dd) and 'name'
  /// - daysBefore: 0..n
  /// - time: TimeOfDay (user chosen)
  /// - enabled: if false, will cancel previously scheduled holiday notifications
  static Future<void> rescheduleHolidayNotifications({
    required List<Map<String, String>> holidays,
    required int daysBefore,
    required TimeOfDay time,
    required bool enabled,
  }) async {
    final settingsBox = Hive.box('settings');

    // Cancel previous holiday notifications (we stored ids list earlier)
    final prev = settingsBox.get('holidayScheduledIds', defaultValue: <int>[]);
    if (prev is List && prev.isNotEmpty) {
      try {
        await cancelNotifications(prev.cast<int>());
      } catch (_) {}
    }

    if (!enabled) {
      // clear stored ids
      settingsBox.put('holidayScheduledIds', <int>[]);
      return;
    }

    final scheduledIds = <int>[];
    final now = DateTime.now();

    for (final h in holidays) {
      final dateStr = h['date']!;
      final name = h['name'] ?? 'Holiday';
      final parts = dateStr.split('-'); // yyyy-mm-dd
      if (parts.length < 3) continue;
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      // notification date for this year
      var notifyDate = DateTime(now.year, month, day)
          .subtract(Duration(days: daysBefore))
          .copyWith(hour: time.hour, minute: time.minute);

      // if already passed this year, schedule next year
      if (notifyDate.isBefore(now)) {
        notifyDate = DateTime(now.year + 1, month, day, time.hour, time.minute);
      }

      final id = holidayNotificationId(dateStr);
      await scheduleNotification(
        id: id,
        title: name,
        body: "Tomorrow is $name",
        scheduledTime: notifyDate,
        repeatYearly: true,
      );
      scheduledIds.add(id);
    }

    // Save scheduled ids
    settingsBox.put('holidayScheduledIds', scheduledIds);
  }

  /// Helper: get android sdk int (best-effort)
  static Future<int> _androidSdkInt() async {
    try {
      // permission_handler provides info; simpler: try to parse system property via Process (may not always work on all environments)
      // but for most cases we can check Permission.scheduleExactAlarm availability using permission_handler directly
      return int.tryParse(await _runGetprop()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<String> _runGetprop() async {
    try {
      // Not always available on all environments; return 0 if fails
      final result = await Process.run('getprop', ['ro.build.version.sdk']);
      return (result.stdout as String).trim();
    } catch (_) {
      return "0";
    }
  }
}

