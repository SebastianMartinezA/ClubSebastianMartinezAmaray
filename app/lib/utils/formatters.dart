import 'package:intl/intl.dart';

/// Date and time helpers.
///
/// The API speaks two formats and the app has to keep them apart:
/// * days: `YYYY-MM-DD` (e.g. `2026-10-17`)
/// * wall-clock times of the venue: `HH:MM:SS` (e.g. `20:00:00`), always on
///   the hour, as the assignment requires one-hour slots.
class Formatters {
  Formatters._();

  static final DateFormat _dayMonthYear = DateFormat('dd/MM/yyyy');
  static final DateFormat _hourMinute = DateFormat('HH:mm');

  static const List<String> _weekdays = <String>[
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const List<String> _months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// `2026-10-17` (the format the API expects in query strings and bodies).
  static String toIsoDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// `2026-10-17` from the API into a `DateTime`.
  static DateTime? parseIsoDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  /// `17/10/2026`.
  static String date(DateTime date) => _dayMonthYear.format(date);

  /// `viernes 17 de octubre de 2026`.
  static String longDate(DateTime date) {
    final String weekday = _weekdays[(date.weekday - 1) % 7];
    final String month = _months[(date.month - 1) % 12];
    return '$weekday ${date.day} de $month de ${date.year}';
  }

  /// `20:00` out of the API value `20:00:00`.
  static String time(String apiTime) {
    final String value = apiTime.length >= 5 ? apiTime.substring(0, 5) : apiTime;
    final DateTime? parsed = DateTime.tryParse('2000-01-01 $value:00');
    if (parsed == null) {
      return value;
    }
    return _hourMinute.format(parsed);
  }

  /// `20:00 a 21:00`.
  static String timeRange(String startTime, String endTime) =>
      '${time(startTime)} a ${time(endTime)}';

  /// Duration in whole hours between two `HH:MM:SS` values, minimum 1.
  static int hoursBetween(String startTime, String endTime) {
    final int start = _minutes(startTime);
    final int end = _minutes(endTime);
    final int hours = ((end - start) / 60).round();
    return hours < 1 ? 1 : hours;
  }

  /// Adds `hours` to a `HH:MM:SS` value, keeping the API format.
  static String addHours(String apiTime, int hours) {
    final int total = _minutes(apiTime) + hours * 60;
    final int hour = (total ~/ 60) % 24;
    final int minute = total % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
  }

  static int _minutes(String apiTime) {
    final List<String> parts = apiTime.split(':');
    final int hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }
}
