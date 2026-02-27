// lib/screens/holiday_settings_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../controller//holiday_service.dart';
import '../controller/notification_service.dart';

class HolidaySettingsPage extends StatefulWidget {
  const HolidaySettingsPage({super.key});

  @override
  State<HolidaySettingsPage> createState() => _HolidaySettingsPageState();
}

class _HolidaySettingsPageState extends State<HolidaySettingsPage> {
  late Box settingsBox;
  bool _enabled = false;
  int _daysBefore = 1;
  TimeOfDay? _time;
  bool _loading = false;
  List<Map<String, String>> _holidays = [];

  @override
  void initState() {
    super.initState();
    settingsBox = Hive.box('settings');
    _enabled = settingsBox.get('holidaysEnabled', defaultValue: false);
    _daysBefore = settingsBox.get('holidaysDaysBefore', defaultValue: 1);
    if (settingsBox.containsKey('holidaysNotifyHour')) {
      _time = TimeOfDay(hour: settingsBox.get('holidaysNotifyHour'), minute: settingsBox.get('holidaysNotifyMinute'));
    } else {
      _time = TimeOfDay(hour: 8, minute: 0);
    }

    _loadHolidaysAndMaybeSchedule();
  }

  Future<void> _loadHolidaysAndMaybeSchedule() async {
    setState(() => _loading = true);
    final year = DateTime.now().year;
    var holidays = await HolidayService.loadLocalHolidays(year);
    if (holidays.isEmpty) {
      try {
        holidays = await HolidayService.fetchBangladeshHolidays(year);
      } catch (e) {
        // ignore fetch error; UI can still toggle
      }
    }
    _holidays = holidays.map((h) => h.toMap()).toList();
    setState(() => _loading = false);

    // if enabled, schedule according to saved settings
    if (_enabled && _time != null) {
      await NotificationService.rescheduleHolidayNotifications(
        holidays: _holidays,
        daysBefore: _daysBefore,
        time: _time!,
        enabled: _enabled,
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 8, minute: 0));
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    // save settings
    settingsBox.put('holidaysEnabled', _enabled);
    settingsBox.put('holidaysDaysBefore', _daysBefore);
    if (_time != null) {
      settingsBox.put('holidaysNotifyHour', _time!.hour);
      settingsBox.put('holidaysNotifyMinute', _time!.minute);
    }

    // schedule/cancel notifications
    await NotificationService.rescheduleHolidayNotifications(
      holidays: _holidays,
      daysBefore: _daysBefore,
      time: _time ?? const TimeOfDay(hour: 8, minute: 0),
      enabled: _enabled,
    );

    Get.snackbar('Saved', _enabled ? 'Holiday notifications scheduled.' : 'Holiday notifications disabled.',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green.shade100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff050d1a),
      appBar: AppBar(
        title: const Text('Holiday Notification Settings'),
        backgroundColor: Color(0xff050d1a),
          foregroundColor: Colors.white
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xff050d1a)),)
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text('Enable holiday notifications', style: TextStyle(color: Color(0xff7e858e))),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              activeColor: Color(0xff1d2150),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Days before event:', style: TextStyle(fontSize: 16, color: Color(0xff7e858e))),
                DropdownButton<int>(
                  value: _daysBefore,
                  style: TextStyle(
                    color: Color(0xff7e858e),
                    fontSize: 16,
                  ),
                  underline: Container(
                    height: 1.5,
                    color: Color(0xff7e858e),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text("Same day")),
                    DropdownMenuItem(value: 1, child: Text("1 day before")),
                    DropdownMenuItem(value: 2, child: Text("2 days before")),
                    DropdownMenuItem(value: 3, child: Text("3 days before")),
                  ],
                  onChanged: (v) => setState(() => _daysBefore = v!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(_time == null ? 'No time selected' : 'Time: ${_time!.format(context)}', style: const TextStyle(fontSize: 16, color: Color(0xff7e858e))),
                ),
                ElevatedButton(
                  onPressed: _pickTime,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, // ব্যাকগ্রাউন্ড সাদা রাখলাম (চাইলে purple করতে পারো)
                    foregroundColor: Color(0xff1d2150), // টেক্সটের রঙ
                    side: const BorderSide(color: Color(0xff1d2150), width: 1.5), // 🔲 বর্ডার
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    elevation: 3, // shadow effect
                  ),
                  child: const Text(
                    'Pick Time',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30,),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff1d2150), // 🔵 ব্যাকগ্রাউন্ড রঙ
                  foregroundColor: Colors.white,  // 🏷️ টেক্সটের রঙ
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 4, // হালকা shadow effect
                ),
                child: const Text('Save Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
