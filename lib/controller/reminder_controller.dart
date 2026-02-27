import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../model/reminder.dart';

class ReminderController extends GetxController {
  var reminders = <Reminder>[].obs;
  late Box<Reminder> box;

  // 🆕 Events set by Developer
  final List<Reminder> developerEvents = [
    // Reminder(
    //   title: 'Victory Day',
    //   description: '',
    //   dateTime: DateTime(2025, 10, 16),
    //   isYearly: true,
    //   isDeveloper: true,
    // ),
    // Reminder(
    //   title: 'New Year',
    //   description: 'Celebrate the New Year!',
    //   dateTime: DateTime(2025, 10, 1),
    //   isYearly: true,
    //   isDeveloper: true,
    // ),
    // Reminder(
    //   title: 'Kichu na',
    //   description: 'Celebrate the New Year!',
    //   dateTime: DateTime(2025, 10, 27),
    //   isYearly: true,
    //   isDeveloper: true,
    // ),
  ];

  @override
  void onInit() {
    super.onInit();
    box = Hive.box<Reminder>('reminders');
    loadReminders();
  }

  void loadReminders() {
    reminders.value = box.values.toList();
  }

  void addReminder(Reminder r) {
    box.add(r);
    reminders.refresh();
    loadReminders();
  }

  void deleteReminderByKey(dynamic key) async {
    await box.delete(key);
    reminders.refresh();
    loadReminders();
  }

  /// User + Developer events return
  List<Reminder> allEventsForDay(DateTime day) {
    // 1st user events
    final user = reminders.where((r) {
      if (r.isYearly) {
        return r.dateTime.month == day.month && r.dateTime.day == day.day;
      } else {
        return r.dateTime.year == day.year &&
            r.dateTime.month == day.month &&
            r.dateTime.day == day.day;
      }
    }).toList();

    // developer events comes first
    final dev = developerEvents.where((r) {
      return r.dateTime.month == day.month && r.dateTime.day == day.day;
    }).toList();

    dev.addAll(user);
    return dev;
  }
}


