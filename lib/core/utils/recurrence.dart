import '../../data/models/recurring_rule.dart';

/// Avance une date d'une occurrence selon la fréquence et l'intervalle.
DateTime advanceDate(DateTime date, RecurrenceFrequency freq, int interval) {
  final n = interval < 1 ? 1 : interval;
  switch (freq) {
    case RecurrenceFrequency.daily:
      return date.add(Duration(days: n));
    case RecurrenceFrequency.weekly:
      return date.add(Duration(days: 7 * n));
    case RecurrenceFrequency.biweekly:
      return date.add(Duration(days: 14 * n));
    case RecurrenceFrequency.monthly:
      return DateTime(date.year, date.month + n, date.day);
    case RecurrenceFrequency.yearly:
      return DateTime(date.year + n, date.month, date.day);
  }
}

/// Libellé court d'une fréquence (FR).
String frequencyLabel(RecurrenceFrequency freq) {
  switch (freq) {
    case RecurrenceFrequency.daily:
      return 'Quotidienne';
    case RecurrenceFrequency.weekly:
      return 'Hebdomadaire';
    case RecurrenceFrequency.biweekly:
      return 'Bi-hebdomadaire';
    case RecurrenceFrequency.monthly:
      return 'Mensuelle';
    case RecurrenceFrequency.yearly:
      return 'Annuelle';
  }
}

/// Génère jusqu'à [maxOccurrences] dates à partir de [start] (incluse),
/// bornées par [end] si fournie.
List<DateTime> generateOccurrences({
  required DateTime start,
  required RecurrenceFrequency freq,
  int interval = 1,
  DateTime? end,
  int maxOccurrences = 24,
}) {
  final dates = <DateTime>[];
  var current = start;
  var count = 0;
  while (count < maxOccurrences) {
    if (end != null && current.isAfter(end)) break;
    dates.add(current);
    current = advanceDate(current, freq, interval);
    count++;
  }
  return dates;
}
