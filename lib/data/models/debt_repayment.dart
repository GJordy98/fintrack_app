import 'package:hive/hive.dart';

import '../hive_config.dart';
import 'sync_status.dart';

part 'debt_repayment.g.dart';

/// État d'une échéance de remboursement (module 3bis).
@HiveType(typeId: HiveTypeIds.repaymentStatus)
enum RepaymentStatus {
  @HiveField(0)
  planned, // prévu
  @HiveField(1)
  paid, // payé
  @HiveField(2)
  late_, // en retard
}

/// Une échéance de remboursement d'une dette, à une date choisie par
/// l'utilisateur. Génère une transaction rattachée quand elle est payée.
@HiveType(typeId: HiveTypeIds.debtRepayment)
class DebtRepayment extends HiveObject {
  DebtRepayment({
    required this.id,
    required this.debtId,
    required this.dueDate,
    required this.amount,
    this.status = RepaymentStatus.planned,
    this.paidDate,
    this.transactionId,
    required this.updatedAt,
    this.syncStatus = SyncStatus.dirty,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  String debtId;

  @HiveField(2)
  DateTime dueDate;

  @HiveField(3)
  int amount;

  @HiveField(4)
  RepaymentStatus status;

  @HiveField(5)
  DateTime? paidDate;

  @HiveField(6)
  String? transactionId;

  @HiveField(7)
  DateTime updatedAt;

  @HiveField(8)
  SyncStatus syncStatus;
}
