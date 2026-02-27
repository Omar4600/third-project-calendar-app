import 'package:hive/hive.dart';

part 'reminder.g.dart';

@HiveType(typeId: 0)
class Reminder extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String description;

  @HiveField(2)
  DateTime dateTime;

  @HiveField(3)
  bool isAlarm;

  @HiveField(4)
  bool isYearly;

  @HiveField(5)                // 🆕  নতুন ফিল্ড
  bool isDeveloper;

  Reminder({
    required this.title,
    required this.description,
    required this.dateTime,
    this.isAlarm = false,
    this.isYearly = false,
    this.isDeveloper = false,  // ডিফল্টভাবে false
  });
}
