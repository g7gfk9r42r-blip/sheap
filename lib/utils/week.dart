/// ISO 8601 week numbering: Returns a string key representing the ISO week.
/// Format: "YYYY-Www" where YYYY is the year, www is the ISO week number (01-53)
/// 
/// Example: 2024-W42 for week 42 of 2024
String isoWeekKey(DateTime date) {
  // Calculate ISO 8601 week number
  final thursday = date.subtract(Duration(days: date.weekday - 4));
  final weekOne = thursday.subtract(Duration(days: thursday.day - 1));
  final weekStart = weekOne.add(Duration(days: -(weekOne.weekday - 1)));
  
  final year = thursday.year;
  final weekNum = ((thursday.difference(weekStart).inDays) ~/ 7) + 1;
  
  return '$year-W${weekNum.toString().padLeft(2, '0')}';
}

/// Get the start date of an ISO week from a week key (format: "YYYY-Www")
DateTime weekStartFromKey(String weekKey) {
  final parts = weekKey.split('-W');
  if (parts.length != 2) {
    throw ArgumentError('Invalid week key format: $weekKey. Expected YYYY-Www');
  }
  
  final year = int.parse(parts[0]);
  final week = int.parse(parts[1]);
  
  // Find January 4th of the given year (always in week 1)
  final jan4 = DateTime(year, 1, 4);
  final weekOne = jan4.subtract(Duration(days: jan4.weekday - 1));
  
  // Calculate the start of the target week
  return weekOne.add(Duration(days: (week - 1) * 7));
}

/// Get the end date of an ISO week from a week key
DateTime weekEndFromKey(String weekKey) {
  return weekStartFromKey(weekKey).add(Duration(days: 6));
}

/// Check if a date falls within a given ISO week
bool isDateInWeek(DateTime date, String weekKey) {
  final start = weekStartFromKey(weekKey);
  final end = weekEndFromKey(weekKey);
  return date.isAfter(start.subtract(Duration(days: 1))) &&
         date.isBefore(end.add(Duration(days: 1)));
}
