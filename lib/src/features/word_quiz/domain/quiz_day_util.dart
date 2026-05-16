/// Computes the quiz day using Almaty timezone (UTC+5) with a 2-hour offset.
/// Quiz day rolls over at 02:00 Almaty time (21:00 UTC previous day).
DateTime getQuizDay() {
  final now = DateTime.now().toUtc();
  // Almaty is UTC+5, minus 2 hours offset = UTC+3 for day boundary
  final almatyAdjusted = now.add(const Duration(hours: 3));
  return DateTime(almatyAdjusted.year, almatyAdjusted.month,
      almatyAdjusted.day);
}

/// Formats a DateTime as yyyy-MM-dd string.
String dateToString(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
