import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'controller/holiday_service.dart';
import 'controller/reminder_controller.dart';
import 'model/reminder.dart';
import 'controller/notification_service.dart';
import 'screen/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // local date format
  await initializeDateFormatting();

  // Hive init
  await Hive.initFlutter();
  Hive.registerAdapter(ReminderAdapter());
  await Hive.openBox<Reminder>('reminders');

  await Hive.openBox('settings');

  // 🔔 Local Notification init
  await NotificationService.init();

  await Permission.notification.request();

  // Android 13+ notification permission
  var status = await Permission.notification.status;
  if (status.isDenied) {
    status = await Permission.notification.request();
  }
  debugPrint("Notification permission: $status");

  // ✅ Register ReminderController
  Get.put(ReminderController());

  runApp(const MainPage());

  final settingsBox = Hive.box('settings');

// Load holidays (from cache or fetch)
  final currentYear = DateTime.now().year;
  List<Map<String, String>> holidaysList = [];
  try {
    final local = await HolidayService.loadLocalHolidays(currentYear);
    if (local.isNotEmpty) {
      holidaysList = local.map((h) => h.toMap()).toList();
    } else {
      final fetched = await HolidayService.fetchBangladeshHolidays(currentYear);
      holidaysList = fetched.map((h) => h.toMap()).toList();
    }
  } catch (e) {
    // ignore fetch error; continue gracefully
  }

// Restore holiday scheduling if user had enabled it
  if (settingsBox.get('holidaysEnabled', defaultValue: false)) {
    final hour = settingsBox.get('holidaysNotifyHour', defaultValue: 8);
    final minute = settingsBox.get('holidaysNotifyMinute', defaultValue: 0);
    final daysBefore = settingsBox.get('holidaysDaysBefore', defaultValue: 1);
    final time = TimeOfDay(hour: hour, minute: minute);

    await NotificationService.rescheduleHolidayNotifications(
      holidays: holidaysList,
      daysBefore: daysBefore,
      time: time,
      enabled: true,
    );
  }



}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashPage(),
    );
  }
}
