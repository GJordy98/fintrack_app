/// Moteur de projection financière — 100 % Dart, sans dépendance à l'UI ni à
/// Hive (module 3.4). Testable indépendamment.
///
/// Principe : à partir d'un solde de départ, d'un flux mensuel net (revenus
/// récurrents − dépenses récurrentes − moyenne des dépenses variables − épargne
/// engagée) et d'événements datés ponctuels (perceptions de tontine, échéances
/// de dettes...), on projette le solde disponible dans le temps.
library;

/// Un mouvement daté ponctuel. `amount` est signé (+ entrée, − sortie).
class ScheduledFlow {
  const ScheduledFlow({required this.date, required this.amount, this.label});
  final DateTime date;
  final int amount;
  final String? label;
}

/// Un point de la courbe de projection.
class ForecastPoint {
  const ForecastPoint(this.date, this.balance);
  final DateTime date;
  final int balance;
}

/// Résultat du simulateur d'achat.
class AffordabilityResult {
  const AffordabilityResult({
    required this.reachable,
    this.date,
    this.months,
  });

  /// L'achat est-il atteignable dans l'horizon considéré ?
  final bool reachable;

  /// Date estimée d'atteignabilité (null si jamais).
  final DateTime? date;

  /// Nombre de mois avant d'y arriver (0 = déjà possible).
  final int? months;
}

class ForecastEngine {
  ForecastEngine._();

  /// Nombre de mois entiers écoulés entre deux dates (peut être négatif).
  static int monthsBetween(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + (to.month - from.month);

  /// Regroupe les flux ponctuels par indice de mois (1..N) relatif à `from`.
  /// Les flux du mois 0 (déjà passés ce mois-ci) sont ignorés côté projection
  /// future ; les flux au-delà de l'horizon aussi.
  static Map<int, int> _flowsByMonth(
    List<ScheduledFlow> flows,
    DateTime from,
    int months,
  ) {
    final map = <int, int>{};
    for (final f in flows) {
      final idx = monthsBetween(from, f.date);
      if (idx >= 1 && idx <= months) {
        map[idx] = (map[idx] ?? 0) + f.amount;
      }
    }
    return map;
  }

  /// Projette le solde sur [months] mois (point 0 = aujourd'hui).
  static List<ForecastPoint> project({
    required int startBalance,
    required int netMonthly,
    required int months,
    required DateTime from,
    List<ScheduledFlow> scheduled = const [],
  }) {
    final byMonth = _flowsByMonth(scheduled, from, months);
    final points = <ForecastPoint>[ForecastPoint(from, startBalance)];
    var balance = startBalance;
    for (var m = 1; m <= months; m++) {
      balance += netMonthly + (byMonth[m] ?? 0);
      points.add(ForecastPoint(DateTime(from.year, from.month + m, from.day),
          balance));
    }
    return points;
  }

  /// Simulateur d'achat : à partir de quand pourra-t-on s'offrir [price] ?
  static AffordabilityResult canAfford({
    required int startBalance,
    required int price,
    required int netMonthly,
    required DateTime from,
    List<ScheduledFlow> scheduled = const [],
    int maxMonths = 120,
  }) {
    if (startBalance >= price) {
      return AffordabilityResult(reachable: true, date: from, months: 0);
    }
    final byMonth = _flowsByMonth(scheduled, from, maxMonths);
    var balance = startBalance;
    for (var m = 1; m <= maxMonths; m++) {
      balance += netMonthly + (byMonth[m] ?? 0);
      if (balance >= price) {
        return AffordabilityResult(
          reachable: true,
          date: DateTime(from.year, from.month + m, from.day),
          months: m,
        );
      }
    }
    return const AffordabilityResult(reachable: false);
  }
}
