import 'package:hive/hive.dart';

import '../hive_config.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/contribution.dart';
import '../models/contribution_event.dart';
import '../models/day_budget.dart';
import '../models/debt.dart';
import '../models/debt_repayment.dart';
import '../models/fixed_charge.dart';
import '../models/goal.dart';
import '../models/goal_status_history.dart';
import '../models/income_profile.dart';
import '../models/recurring_rule.dart';
import '../models/sync_status.dart';
import '../models/transaction.dart';

// --- Helpers de (dé)sérialisation ---
int _i(dynamic v) => (v as num).toInt();
int? _in(dynamic v) => v == null ? null : (v as num).toInt();
String _s(dynamic v) => v as String;
String? _sn(dynamic v) => v as String?;
bool _b(dynamic v, [bool d = false]) => v == null ? d : v as bool;
String _iso(DateTime d) => d.toIso8601String();
DateTime _dt(dynamic v) => DateTime.parse(v as String);
DateTime? _dtn(dynamic v) => v == null ? null : DateTime.parse(v as String);

/// Un enregistrement local prêt à être envoyé au serveur.
class SyncItem {
  SyncItem(this.entityId, this.payload, this.clientUpdatedAt);
  final String entityId;
  final Map<String, dynamic> payload;
  final DateTime clientUpdatedAt;
}

/// Interface non générique manipulée par le SyncService.
abstract class ISyncBucket {
  String get type;

  /// Entités non encore synchronisées (syncStatus != synced).
  List<SyncItem> collectDirty();

  /// Marque des entités comme synchronisées.
  void markSynced(Iterable<String> ids);

  /// Applique une entité venue du serveur (upsert / suppression), en respectant
  /// le last-write-wins.
  void applyRemote(
      String id, Map<String, dynamic> payload, bool deleted, DateTime clientUpdatedAt);
}

/// Implémentation générique d'un bucket de synchronisation pour un type Hive.
class SyncBucket<T extends HiveObject> implements ISyncBucket {
  SyncBucket({
    required this.type,
    required this.box,
    required this.getId,
    required this.getUpdatedAt,
    required this.getStatus,
    required this.setStatus,
    required this.toMap,
    required this.fromMap,
  });

  @override
  final String type;
  final Box<T> box;
  final String Function(T) getId;
  final DateTime Function(T) getUpdatedAt;
  final SyncStatus Function(T) getStatus;
  final void Function(T, SyncStatus) setStatus;
  final Map<String, dynamic> Function(T) toMap;
  final T Function(Map<String, dynamic>) fromMap;

  @override
  List<SyncItem> collectDirty() {
    final items = <SyncItem>[];
    for (final e in box.values) {
      if (getStatus(e) == SyncStatus.synced) continue;
      items.add(SyncItem(getId(e), toMap(e), getUpdatedAt(e)));
    }
    return items;
  }

  @override
  void markSynced(Iterable<String> ids) {
    for (final id in ids) {
      final e = box.get(id);
      if (e != null) {
        setStatus(e, SyncStatus.synced);
        box.put(id, e);
      }
    }
  }

  @override
  void applyRemote(String id, Map<String, dynamic> payload, bool deleted,
      DateTime clientUpdatedAt) {
    final existing = box.get(id);
    if (existing != null) {
      // Last-write-wins : on garde la version locale si elle est plus récente.
      if (getUpdatedAt(existing).isAfter(clientUpdatedAt)) return;
    }
    if (deleted) {
      box.delete(id);
      return;
    }
    final entity = fromMap(payload);
    setStatus(entity, SyncStatus.synced);
    box.put(id, entity);
  }
}

/// Construit tous les buckets à partir des boîtes Hive ouvertes.
List<ISyncBucket> buildSyncBuckets() {
  return [
    SyncBucket<Account>(
      type: 'account',
      box: Hive.box<Account>(HiveBoxes.accounts),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'name': e.name,
        'type': e.type.index,
        'initialBalance': e.initialBalance,
        'currencyCode': e.currencyCode,
        'colorValue': e.colorValue,
        'iconCodePoint': e.iconCodePoint,
        'archived': e.archived,
        'provider': e.provider,
        'bankName': e.bankName,
        'bankAccountKind': e.bankAccountKind,
        'createdAt': _iso(e.createdAt),
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => Account(
        id: _s(m['id']),
        name: _s(m['name']),
        type: AccountType.values[_i(m['type'])],
        initialBalance: _i(m['initialBalance']),
        currencyCode: _s(m['currencyCode']),
        colorValue: _in(m['colorValue']),
        iconCodePoint: _in(m['iconCodePoint']),
        archived: _b(m['archived']),
        provider: _sn(m['provider']),
        bankName: _sn(m['bankName']),
        bankAccountKind: _sn(m['bankAccountKind']),
        createdAt: _dt(m['createdAt']),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
    SyncBucket<Category>(
      type: 'category',
      box: Hive.box<Category>(HiveBoxes.categories),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'name': e.name,
        'kind': e.kind.index,
        'iconCodePoint': e.iconCodePoint,
        'colorValue': e.colorValue,
        'isCustom': e.isCustom,
        'archived': e.archived,
        'isFixed': e.isFixed,
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => Category(
        id: _s(m['id']),
        name: _s(m['name']),
        kind: CategoryKind.values[_i(m['kind'])],
        iconCodePoint: _i(m['iconCodePoint']),
        colorValue: _i(m['colorValue']),
        isCustom: _b(m['isCustom']),
        archived: _b(m['archived']),
        isFixed: _b(m['isFixed']),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
    SyncBucket<AppTransaction>(
      type: 'transaction',
      box: Hive.box<AppTransaction>(HiveBoxes.transactions),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'amount': e.amount,
        'type': e.type.index,
        'accountId': e.accountId,
        'categoryId': e.categoryId,
        'note': e.note,
        'date': _iso(e.date),
        'photoPath': e.photoPath,
        'recurringRuleId': e.recurringRuleId,
        'createdAt': _iso(e.createdAt),
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => AppTransaction(
        id: _s(m['id']),
        amount: _i(m['amount']),
        type: TransactionType.values[_i(m['type'])],
        accountId: _s(m['accountId']),
        categoryId: _sn(m['categoryId']),
        note: _sn(m['note']),
        date: _dt(m['date']),
        photoPath: _sn(m['photoPath']),
        recurringRuleId: _sn(m['recurringRuleId']),
        createdAt: _dt(m['createdAt']),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
    SyncBucket<RecurringRule>(
      type: 'recurring_rule',
      box: Hive.box<RecurringRule>(HiveBoxes.recurringRules),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'label': e.label,
        'amount': e.amount,
        'type': e.type.index,
        'accountId': e.accountId,
        'categoryId': e.categoryId,
        'frequency': e.frequency.index,
        'interval': e.interval,
        'startDate': _iso(e.startDate),
        'nextRun': _iso(e.nextRun),
        'endDate': e.endDate == null ? null : _iso(e.endDate!),
        'active': e.active,
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => RecurringRule(
        id: _s(m['id']),
        label: _s(m['label']),
        amount: _i(m['amount']),
        type: TransactionType.values[_i(m['type'])],
        accountId: _s(m['accountId']),
        categoryId: _sn(m['categoryId']),
        frequency: RecurrenceFrequency.values[_i(m['frequency'])],
        interval: _i(m['interval']),
        startDate: _dt(m['startDate']),
        nextRun: _dt(m['nextRun']),
        endDate: _dtn(m['endDate']),
        active: _b(m['active'], true),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
    SyncBucket<Budget>(
      type: 'budget',
      box: Hive.box<Budget>(HiveBoxes.budgets),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'categoryId': e.categoryId,
        'month': e.month,
        'allocated': e.allocated,
        'rollover': e.rollover,
        'alertThresholdPercent': e.alertThresholdPercent,
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => Budget(
        id: _s(m['id']),
        categoryId: _s(m['categoryId']),
        month: _s(m['month']),
        allocated: _i(m['allocated']),
        rollover: _b(m['rollover']),
        alertThresholdPercent: _i(m['alertThresholdPercent']),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
    SyncBucket<Goal>(
      type: 'goal',
      box: Hive.box<Goal>(HiveBoxes.goals),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'name': e.name,
        'targetAmount': e.targetAmount,
        'currentAmount': e.currentAmount,
        'targetDate': e.targetDate == null ? null : _iso(e.targetDate!),
        'colorValue': e.colorValue,
        'iconCodePoint': e.iconCodePoint,
        'priority': e.priority,
        'status': e.status.index,
        'monthlyContribution': e.monthlyContribution,
        'createdAt': _iso(e.createdAt),
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => Goal(
        id: _s(m['id']),
        name: _s(m['name']),
        targetAmount: _i(m['targetAmount']),
        currentAmount: _i(m['currentAmount']),
        targetDate: _dtn(m['targetDate']),
        colorValue: _in(m['colorValue']),
        iconCodePoint: _in(m['iconCodePoint']),
        priority: _i(m['priority']),
        status: GoalStatus.values[_i(m['status'])],
        monthlyContribution: _i(m['monthlyContribution']),
        createdAt: _dt(m['createdAt']),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
    SyncBucket<GoalStatusHistory>(
      type: 'goal_status_history',
      box: Hive.box<GoalStatusHistory>(HiveBoxes.goalStatusHistory),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.date,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'goalId': e.goalId,
        'status': e.status.index,
        'date': _iso(e.date),
        'amountAtEvaluation': e.amountAtEvaluation,
        'acknowledged': e.acknowledged,
      },
      fromMap: (m) => GoalStatusHistory(
        id: _s(m['id']),
        goalId: _s(m['goalId']),
        status: GoalStatus.values[_i(m['status'])],
        date: _dt(m['date']),
        amountAtEvaluation: _i(m['amountAtEvaluation']),
        acknowledged: _b(m['acknowledged']),
      ),
    ),
    SyncBucket<Contribution>(
      type: 'contribution',
      box: Hive.box<Contribution>(HiveBoxes.contributions),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'name': e.name,
        'contributionAmount': e.contributionAmount,
        'expectedPayoutAmount': e.expectedPayoutAmount,
        'frequency': e.frequency.index,
        'interval': e.interval,
        'accountId': e.accountId,
        'startDate': _iso(e.startDate),
        'endDate': e.endDate == null ? null : _iso(e.endDate!),
        'active': e.active,
        'createdAt': _iso(e.createdAt),
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => Contribution(
        id: _s(m['id']),
        name: _s(m['name']),
        contributionAmount: _i(m['contributionAmount']),
        expectedPayoutAmount: _i(m['expectedPayoutAmount']),
        frequency: RecurrenceFrequency.values[_i(m['frequency'])],
        interval: _i(m['interval']),
        accountId: _s(m['accountId']),
        startDate: _dt(m['startDate']),
        endDate: _dtn(m['endDate']),
        active: _b(m['active'], true),
        createdAt: _dt(m['createdAt']),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
    SyncBucket<ContributionEvent>(
      type: 'contribution_event',
      box: Hive.box<ContributionEvent>(HiveBoxes.contributionEvents),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'contributionId': e.contributionId,
        'date': _iso(e.date),
        'kind': e.kind.index,
        'amount': e.amount,
        'status': e.status.index,
        'transactionId': e.transactionId,
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => ContributionEvent(
        id: _s(m['id']),
        contributionId: _s(m['contributionId']),
        date: _dt(m['date']),
        kind: ContributionEventKind.values[_i(m['kind'])],
        amount: _i(m['amount']),
        status: EventStatus.values[_i(m['status'])],
        transactionId: _sn(m['transactionId']),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
    SyncBucket<Debt>(
      type: 'debt',
      box: Hive.box<Debt>(HiveBoxes.debts),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'direction': e.direction.index,
        'counterparty': e.counterparty,
        'principal': e.principal,
        'reason': e.reason,
        'contractedDate': _iso(e.contractedDate),
        'accountId': e.accountId,
        'status': e.status.index,
        'createdAt': _iso(e.createdAt),
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => Debt(
        id: _s(m['id']),
        direction: DebtDirection.values[_i(m['direction'])],
        counterparty: _s(m['counterparty']),
        principal: _i(m['principal']),
        reason: _sn(m['reason']),
        contractedDate: _dt(m['contractedDate']),
        accountId: _sn(m['accountId']),
        status: DebtStatus.values[_i(m['status'])],
        createdAt: _dt(m['createdAt']),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
    SyncBucket<DebtRepayment>(
      type: 'debt_repayment',
      box: Hive.box<DebtRepayment>(HiveBoxes.debtRepayments),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'debtId': e.debtId,
        'dueDate': _iso(e.dueDate),
        'amount': e.amount,
        'status': e.status.index,
        'paidDate': e.paidDate == null ? null : _iso(e.paidDate!),
        'transactionId': e.transactionId,
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => DebtRepayment(
        id: _s(m['id']),
        debtId: _s(m['debtId']),
        dueDate: _dt(m['dueDate']),
        amount: _i(m['amount']),
        status: RepaymentStatus.values[_i(m['status'])],
        paidDate: _dtn(m['paidDate']),
        transactionId: _sn(m['transactionId']),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
    SyncBucket<IncomeProfile>(
      type: 'income_profile',
      box: Hive.box<IncomeProfile>(HiveBoxes.incomeProfiles),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'label': e.label,
        'amount': e.amount,
        'frequency': e.frequency.index,
        'active': e.active,
        'createdAt': _iso(e.createdAt),
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => IncomeProfile(
        id: _s(m['id']),
        label: _s(m['label']),
        amount: _i(m['amount']),
        frequency: RecurrenceFrequency.values[_i(m['frequency'])],
        active: _b(m['active'], true),
        createdAt: _dt(m['createdAt']),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
    SyncBucket<DayBudget>(
      type: 'day_budget',
      box: Hive.box<DayBudget>(HiveBoxes.dayBudgets),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'date': _iso(e.date),
        'planned': e.planned,
        'actual': e.actual,
        'note': e.note,
        'settled': e.settled,
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => DayBudget(
        id: _s(m['id']),
        date: _dt(m['date']),
        planned: _i(m['planned']),
        actual: _in(m['actual']),
        note: _sn(m['note']),
        settled: _b(m['settled']),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
    SyncBucket<FixedCharge>(
      type: 'fixed_charge',
      box: Hive.box<FixedCharge>(HiveBoxes.fixedCharges),
      getId: (e) => e.id,
      getUpdatedAt: (e) => e.updatedAt,
      getStatus: (e) => e.syncStatus,
      setStatus: (e, s) => e.syncStatus = s,
      toMap: (e) => {
        'id': e.id,
        'label': e.label,
        'amount': e.amount,
        'frequency': e.frequency.index,
        'active': e.active,
        'createdAt': _iso(e.createdAt),
        'updatedAt': _iso(e.updatedAt),
      },
      fromMap: (m) => FixedCharge(
        id: _s(m['id']),
        label: _s(m['label']),
        amount: _i(m['amount']),
        frequency: RecurrenceFrequency.values[_i(m['frequency'])],
        active: _b(m['active'], true),
        createdAt: _dt(m['createdAt']),
        updatedAt: _dt(m['updatedAt']),
      ),
    ),
  ];
}
