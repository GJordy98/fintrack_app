import 'package:uuid/uuid.dart';

import '../core/utils/recurrence.dart';
import 'models/sync_status.dart';
import 'models/transaction.dart';
import 'repositories/recurring_rule_repository.dart';
import 'repositories/transaction_repository.dart';

/// Génère automatiquement les transactions dues à partir des règles récurrentes
/// (salaire, loyer, abonnements...). Idempotent : `nextRun` avance à chaque
/// occurrence générée et est persisté, donc pas de doublon au relancement.
class RecurringGenerator {
  RecurringGenerator(this._rules, this._transactions);

  final RecurringRuleRepository _rules;
  final TransactionRepository _transactions;
  static const _uuid = Uuid();

  /// Nombre max d'occurrences générées par règle en un passage (garde-fou).
  static const int _maxCatchUp = 120;

  Future<int> generateDue({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final cap = DateTime(today.year, today.month, today.day);
    var created = 0;

    for (final rule in _rules.getActive()) {
      var next = rule.nextRun;
      var iterations = 0;
      while (!next.isAfter(cap) && iterations < _maxCatchUp) {
        if (rule.endDate != null && next.isAfter(rule.endDate!)) break;

        final ts = DateTime.now();
        await _transactions.save(AppTransaction(
          id: _uuid.v4(),
          amount: rule.amount,
          type: rule.type,
          accountId: rule.accountId,
          categoryId: rule.categoryId,
          note: rule.label,
          date: next,
          recurringRuleId: rule.id,
          createdAt: ts,
          updatedAt: ts,
          syncStatus: SyncStatus.dirty,
        ));
        created++;

        next = advanceDate(next, rule.frequency, rule.interval);
        // Persiste l'avancement à chaque étape (robuste aux interruptions).
        rule
          ..nextRun = next
          ..updatedAt = DateTime.now()
          ..syncStatus = SyncStatus.dirty;
        await _rules.save(rule);
        iterations++;
      }
    }
    return created;
  }
}
