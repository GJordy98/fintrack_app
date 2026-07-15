import 'package:hive/hive.dart';

import '../models/debt.dart';
import '../models/debt_repayment.dart';
import 'base_repository.dart';

/// Repository des dettes et de leurs échéances de remboursement.
class DebtRepository extends BaseRepository<Debt> {
  DebtRepository(super.box, this._repayments);

  final Box<DebtRepayment> _repayments;

  @override
  String keyOf(Debt entity) => entity.id;

  List<Debt> byDirection(DebtDirection direction) =>
      getAll().where((d) => d.direction == direction).toList();

  // --- Échéances de remboursement ---

  Stream<BoxEvent> watchRepayments() => _repayments.watch();

  Future<void> saveRepayment(DebtRepayment r) => _repayments.put(r.id, r);

  Future<void> deleteRepayment(String id) => _repayments.delete(id);

  DebtRepayment? getRepayment(String id) => _repayments.get(id);

  List<DebtRepayment> repaymentsFor(String debtId) {
    final list =
        _repayments.values.where((r) => r.debtId == debtId).toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  List<DebtRepayment> allRepayments() => _repayments.values.toList();

  Future<void> deleteWithRepayments(String debtId) async {
    final ids =
        repaymentsFor(debtId).map((r) => r.id).toList(growable: false);
    for (final id in ids) {
      await _repayments.delete(id);
    }
    await delete(debtId);
  }

  /// Total déjà remboursé (échéances payées).
  int paidTotal(String debtId) {
    var total = 0;
    for (final r in repaymentsFor(debtId)) {
      if (r.status == RepaymentStatus.paid) total += r.amount;
    }
    return total;
  }

  /// Reste à payer = principal − remboursements payés.
  int remaining(Debt debt) =>
      (debt.principal - paidTotal(debt.id)).clamp(0, debt.principal);
}
