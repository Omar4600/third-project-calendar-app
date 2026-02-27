import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class Holiday {
  final String name;
  final DateTime date;

  Holiday({required this.name, required this.date});

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      name: json['name'],
      date: DateTime.parse(json['date']['iso']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'date': date.toIso8601String(),
  };

  Map<String, String> toMap() => {
    'name': name,
    'date': date.toIso8601String(),
  };
}

class HolidayService {
  static const _boxName = 'holidaysBox';

  /// 🔑 API key
  static const _apiKey = "wKVY2QSGzcPjjbl2UsKuIBPNzlA3iDVv";

  static Future<List<Holiday>> fetchBangladeshHolidays(int year) async {
    try {
      final url = Uri.parse(
          "https://calendarific.com/api/v2/holidays?api_key=$_apiKey&country=BD&year=$year");

      print("🌍 Fetching: $url");

      final res = await http.get(url);

      print("🌍 Status Code: ${res.statusCode}");
      print("🌍 Body: ${res.body}");

      if (res.statusCode != 200) {
        throw Exception("API Failed with ${res.statusCode}");
      }

      final body = jsonDecode(res.body);

      final List holidaysJson = body['response']['holidays'];

      final holidays = holidaysJson.map((e) {
        return Holiday(
          name: e['name'],
          date: DateTime.parse(e['date']['iso']),
        );
      }).toList();

      /// Cache to Hive
      final box = await Hive.openBox(_boxName);
      await box.put(
          year.toString(),
          holidays.map((h) => h.toJson()).toList()
      );

      return holidays;
    } catch (e) {
      print("❌ Holiday fetch error: $e");
      rethrow;
    }
  }

  static Future<List<Holiday>> loadLocalHolidays(int year) async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(year.toString(), defaultValue: []);

    if (data.isEmpty) return [];

    return (data as List)
        .map((e) => Holiday(
      name: e['name'],
      date: DateTime.parse(e['date']),
    )).toList();
  }
}