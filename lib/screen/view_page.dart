import 'package:auremainder/screen/holiday_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../controller/notification_service.dart';
import '../controller/reminder_controller.dart';
import 'add_event_page.dart';
import '../controller/holiday_service.dart'; // ✅ Holiday API import

class ViewPage extends StatefulWidget {
  const ViewPage({super.key});

  @override
  State<ViewPage> createState() => _ViewPageState();
}

class _ViewPageState extends State<ViewPage> {
  final ReminderController controller = Get.put(ReminderController());
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// ✅ Holidays variables
  List<Holiday> _holidays = [];
  bool _isLoadingHolidays = true;

  @override
  void initState() {
    super.initState();
    _loadHolidaysForYear(DateTime.now().year);
  }

  /// 🧱 Holidays load (local + API)
  Future<void> _loadHolidaysForYear(int year) async {
    setState(() => _isLoadingHolidays = true);

    try {
      final local = await HolidayService.loadLocalHolidays(year);
      if (local.isNotEmpty) {
        _holidays = local;
      } else {
        _holidays =
        await HolidayService.fetchBangladeshHolidays(year);
      }
    } catch (e) {
      print("Holiday error: $e");
    }

    setState(() => _isLoadingHolidays = false);
  }

  /// ✅ Add event popup (user event add)
  void _showAddPrompt(DateTime day) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add event on ${day.day}-${day.month}-${day.year}?',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff1d2150),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add Event',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.pop(context);
                    Get.to(() => AddEventPage(selectedDate: day));
                  },
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  /// ✅ Day events loader (user + holidays)
  List _eventsForDay(DateTime day) {
    final userEvents = controller.allEventsForDay(day);
    final holidayEvents = _holidays.where((h) {
      final d = h.date;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
    return [...userEvents, ...holidayEvents];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff050d1a),
      body: Column(
        children: [
          const SizedBox(height: 30),
          Obx(() {
            // 👇 MUST use observable inside Obx
            final reminderCount = controller.reminders.length;

            return TableCalendar(
              focusedDay: _focusedDay,
              firstDay: DateTime.utc(2010, 1, 1),
              lastDay: DateTime.utc(2040, 12, 31),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,

              onPageChanged: (focusedDay) {

                // Check if month actually changed
                final monthChanged =
                    _focusedDay.month != focusedDay.month ||
                        _focusedDay.year != focusedDay.year;

                setState(() {
                  _focusedDay = focusedDay;

                  if (monthChanged) {
                    final firstDayOfMonth =
                    DateTime(focusedDay.year, focusedDay.month, 1);

                    _selectedDay = firstDayOfMonth;
                    selectedDate.value = firstDayOfMonth;
                  }
                });

                if (monthChanged) {
                  _loadHolidaysForYear(focusedDay.year);
                }
              },

              eventLoader: (day) {
                return controller.allEventsForDay(day);
              },

              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  selectedDate.value = selectedDay;
                });
              },

              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                decoration: BoxDecoration(
                  color: Color(0xff050d1a),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
              ),

              onFormatChanged: (format) =>
                  setState(() => _calendarFormat = format),

              calendarBuilders: CalendarBuilders(
                dowBuilder: (context, day) {
                  final text = DateFormat.E().format(day);
                  if (day.weekday == DateTime.friday ||
                      day.weekday == DateTime.saturday) {
                    return Center(
                      child: Text(
                        day.weekday == DateTime.friday ? 'Fri' : 'Sat',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }
                  return Center(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                },

                defaultBuilder: (context, day, focusedDay) {
                  if (day.weekday == DateTime.friday ||
                      day.weekday == DateTime.saturday) {
                    return _dayCell(day, textColor: Colors.redAccent);
                  }
                  return _dayCell(day, textColor: Colors.white);
                },

                todayBuilder: (context, day, focusDay) {
                  return _dayCell(
                    day,
                    textColor: Colors.white,
                    bgColor: const Color(0xff1db48c),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.7), width: 1),
                  );
                },

                selectedBuilder: (context, day, focusDay) {
                  return _dayCell(
                    day,
                    textColor: Colors.white,
                    bgColor: const Color(0xff1db48c).withOpacity(0.45),
                  );
                },

                markerBuilder: (context, date, events) {

                  /// 🔴 Holiday check
                  final isHoliday = _holidays.any((h) =>
                  h.date.year == date.year &&
                      h.date.month == date.month &&
                      h.date.day == date.day);

                  /// 🟡 User events check
                  final userEvents =
                  controller.allEventsForDay(date);

                  if (!isHoliday && userEvents.isEmpty) return null;

                  return Positioned(
                    bottom: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        /// 🔴 Holiday dot
                        if (isHoliday)
                          Container(
                            margin:
                            const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),

                        /// 🟡 User event dot
                        if (userEvents.isNotEmpty)
                          Container(
                            margin:
                            const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xffffda07),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 10),
          Expanded(
            child: Obx(() {
              final dailyReminders = controller.allEventsForDay(selectedDate.value);
              final userEvents =
              dailyReminders.where((e) => !e.isDeveloper).toList();

              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xff050d1a),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                    topRight: Radius.circular(30.0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
                      child: Text(
                        "Events on ${DateFormat('d MMM yyyy').format(selectedDate.value)}",
                        style: const TextStyle(fontSize: 14, color: Color(0xff7e858e)),
                      ),
                    ),
                    Expanded(
                      child: _isLoadingHolidays
                          ? const Center(
                          child: CircularProgressIndicator(color: Color(0xff1db48c)))
                          : Obx(() {
                        final selected = selectedDate.value;

                        /// 🎯 Only selected date holidays
                        final selectedHolidays = _holidays.where((h) =>
                        h.date.year == selected.year &&
                            h.date.month == selected.month &&
                            h.date.day == selected.day).toList();

                        /// 🎯 Only selected date user events
                        final dailyReminders =
                        controller.allEventsForDay(selected);
                        final userEvents =
                        dailyReminders.where((e) => !e.isDeveloper).toList();

                        if (selectedHolidays.isEmpty && userEvents.isEmpty) {
                          return const Center(
                            child: Text(
                              "No events found",
                              style:
                              TextStyle(color: Color(0xff7e858e), fontSize: 16),
                            ),
                          );
                        }

                        return ListView(
                          children: [

                            /// ✅ Holidays First
                            ...selectedHolidays.map((holiday) => Container(
                              margin: const EdgeInsets.only(
                                  left: 14, right: 14, bottom: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xff0a1930),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                title: Text(
                                  holiday.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                                // subtitle: Text(
                                //   DateFormat('d MMM yyyy')
                                //       .format(holiday.date),
                                //   style: const TextStyle(
                                //       color: Color(0xff7e858e),
                                //       fontSize: 12),
                                // ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.watch_later,
                                      color: Color(0xff666e81)),
                                  onPressed: () {
                                    Get.to(() => HolidaySettingsPage());
                                  },
                                ),
                                onTap: () {
                                  _showHolidayNotificationDialog(
                                      holiday);
                                },
                              ),
                            )),

                            /// ✅ User Events Section (only if exists)
                            if (userEvents.isNotEmpty)
                              const Padding(
                                padding:
                                EdgeInsets.only(left: 18, bottom: 8, top: 10),
                                child: Text(
                                  "Personal Events",
                                  style: TextStyle(
                                      color: Color(0xff7e858e), fontSize: 14),
                                ),
                              ),

                            ...userEvents.map((reminder) => Container(
                              margin: const EdgeInsets.only(
                                  left: 14, right: 14, bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xff1d2150),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                title: Text(reminder.title,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Color(0xff666e81)),
                                  onPressed: () =>
                                      controller.deleteReminderByKey(
                                          reminder.key),
                                ),
                              ),
                            )),
                          ],
                        );
                      }),
                    )
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// ✅ Day cell UI
  Widget _dayCell(DateTime day,
      {Color textColor = Colors.black, Color? bgColor, BoxBorder? border}) {
    return GestureDetector(
      onDoubleTap: () => _showAddPrompt(day),
      onLongPress: () => _showAddPrompt(day),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(color: textColor, fontSize: 14),
        ),
      ),
    );
  }

  void _showHolidayNotificationDialog(Holiday holiday) async {
    TimeOfDay selectedTime =
    const TimeOfDay(hour: 8, minute: 0);

    int daysBefore = 1;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Set notification for ${holiday.name}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: daysBefore,
                items: const [
                  DropdownMenuItem(value: 0, child: Text("Same day")),
                  DropdownMenuItem(value: 1, child: Text("1 day before")),
                  DropdownMenuItem(value: 2, child: Text("2 days before")),
                ],
                onChanged: (v) {
                  daysBefore = v!;
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                child: const Text("Pick Time"),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (picked != null) {
                    selectedTime = picked;
                  }
                },
              )
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Save"),
              onPressed: () async {
                final notifyDate = holiday.date
                    .subtract(Duration(days: daysBefore))
                    .copyWith(
                  hour: selectedTime.hour,
                  minute: selectedTime.minute,
                );

                final id = holiday.date.hashCode;

                await NotificationService.scheduleNotification(
                  id: id,
                  title: holiday.name,
                  body: "Upcoming holiday",
                  scheduledTime: notifyDate,
                );

                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
