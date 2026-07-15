import '../../data/models/contribution_event.dart';
import '../../data/models/debt.dart';
import '../../data/models/debt_repayment.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import 'forecast_engine.dart';

/// Résultat d'assemblage des entrées de prévision, prêt pour [ForecastEngine].
class ForecastInputs {
  const ForecastInputs({
    required this.startBalance,
    required this.netMonthly,
    required this.avgMonthlyIncome,
    required this.avgMonthlyExpense,
    required this.scheduled,
    required this.windowMonths,
  });

  final int startBalance;
  final int netMonthly;
  final int avgMonthlyIncome;
  final int avgMonthlyExpense;
  final List<ScheduledFlow> scheduled;
  final int windowMonths;
}

/// Assemble les entrées du moteur de prévision à partir des données locales.
///
/// Le flux mensuel net est estimé sur l'historique glissant (3 ou 6 mois) des
/// entrées/sorties réelles — approche robuste pour une saisie manuelle. Les
/// événements datés (cotisations à percevoir/verser, échéances de dettes) sont
/// ajoutés comme flux ponctuels.
class ForecastService {
  ForecastService(
    this._accounts,
    this._transactions,
    this._contributionEvents,
    this._debtRepayments,
    this._debts,
  );

  final AccountRepository _accounts;
  final TransactionRepository _transactions;
  final List<ContributionEvent> Function() _contributionEvents;
  final List<DebtRepayment> Function() _debtRepayments;
  final List<Debt> Function() _debts;

  ForecastInputs build({int windowMonths = 3, DateTime? now}) {
    final today = now ?? DateTime.now();
    final txs = _transactions.getAll();
    final startBalance = _accounts.consolidatedBalance(txs);

    // Fenêtre glissante : depuis le 1er jour, il y a `windowMonths` mois.
    final windowStart = DateTime(today.year, today.month - windowMonths, 1);
    var income = 0;
    var expense = 0;
    for (final t in txs) {
      if (t.date.isBefore(windowStart) || t.date.isAfter(today)) continue;
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    final avgIncome = (income / windowMonths).round();
    final avgExpense = (expense / windowMonths).round();
    final netMonthly = avgIncome - avgExpense;

    // Flux ponctuels futurs.
    final scheduled = <ScheduledFlow>[];
    for (final e in _contributionEvents()) {
      if (e.status == EventStatus.upcoming && e.date.isAfter(today)) {
        scheduled.add(ScheduledFlow(date: e.date, amount: e.signedAmount));
      }
    }
    final debtDir = {for (final d in _debts()) d.id: d.direction};
    for (final r in _debtRepayments()) {
      if (r.status == RepaymentStatus.planned && r.dueDate.isAfter(today)) {
        // « je dois » -> sortie ; « on me doit » -> entrée.
        final sign =
            debtDir[r.debtId] == DebtDirection.owedToMe ? 1 : -1;
        scheduled.add(ScheduledFlow(date: r.dueDate, amount: sign * r.amount));
      }
    }

    return ForecastInputs(
      startBalance: startBalance,
      netMonthly: netMonthly,
      avgMonthlyIncome: avgIncome,
      avgMonthlyExpense: avgExpense,
      scheduled: scheduled,
      windowMonths: windowMonths,
    );
  }
}
