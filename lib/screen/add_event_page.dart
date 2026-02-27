import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controller/reminder_controller.dart';
import '../model/reminder.dart';
import '../services/notification_service.dart';

class AddEventPage extends StatefulWidget {
  final DateTime selectedDate;
  const AddEventPage({super.key, required this.selectedDate});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final ReminderController _ctrl = Get.find();
  TimeOfDay? _time;
  bool _isYearly = false;

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) setState(() => _time = t);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final dt = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _time?.hour ?? 0,
      _time?.minute ?? 0,
    );

    final reminder = Reminder(
      title: _title.text.trim(),
      description: _desc.text.trim(),
      dateTime: dt,
      isYearly: _isYearly,
    );

    _ctrl.addReminder(reminder);

    NotificationService.scheduleNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: reminder.title,
      body: reminder.description,
      scheduledTime: dt,
      repeatYearly: _isYearly,
    );

    Get.back();
    Get.snackbar(
      'Success',
      _isYearly
          ? 'Yearly Event added on ${DateFormat.MMMd().format(dt)}'
          : 'Event added on ${DateFormat.yMMMd().format(dt)}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.purple.shade100,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff050d1a),
      appBar: AppBar(
          title: const Text('Add Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
        backgroundColor: Color(0xff050d1a),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Selected: ${DateFormat.yMMMd().format(widget.selectedDate)}', style: TextStyle(color: Color(0xff7e858e)),),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                cursorColor: Color(0xff1d2150),
                style: TextStyle(color: Color(0xffffffff)),
                autovalidateMode: AutovalidateMode.onUserInteraction, // 🔹 ensures validation
                decoration: InputDecoration(
                  labelText: 'Add Event',
                  labelStyle: const TextStyle(color: Color(0xff7e858e)),
                  // Normal border
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xff7e858e), width: 1.5),
                  ),
                  // Focused border
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xff1d2150), width: 2),
                  ),
                  // Error border
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  // Padding inside input box
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter title' : null,
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(_time == null
                        ? 'No time selected'
                        : 'Time: ${_time!.format(context)}',style: TextStyle(fontSize: 16, color: Color(0xff7e858e)),),
                  ),
                  ElevatedButton(
                    onPressed: _pickTime,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xff1d2150), // txt clr
                      side: const BorderSide(color: Color(0xff1d2150), width: 1.5), // 🔲 Border
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
                  )

                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Repeat every year',
                    style: TextStyle(fontSize: 16, color: Color(0xff7e858e)),
                  ),
                  Switch(
                    value: _isYearly,
                    onChanged: (v) => setState(() => _isYearly = v),
                    activeColor: Color(0xff1d2150),
                  ),
                ],
              ),
              // SwitchListTile(
              //   title: const Text('Repeat every year'),
              //   value: _isYearly,
              //   onChanged: (v) => setState(() => _isYearly = v),
              // ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff1d2150),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 4, // Little bit shadow effect
                ),
                child: const Text(
                  'Save Event',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
