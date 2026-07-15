import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../data/models/debt.dart';
import '../../data/models/debt_repayment.dart';
import 'cubit/debts_cubit.dart';
import 'widgets/debt_editor_sheet.dart';

class DebtDetailPage extends StatelessWidget {
  const DebtDetailPage({super.key, required this.debtId});
  final String debtId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DebtsCubit, DebtsState>(
      builder: (context, state) {
        final cubit = context.read<DebtsCubit>();
        final match =
            state.debts.where((v) => v.debt.id == debtId).toList();
        if (match.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Dette introuvable')),
          );
        }
        final view = match.first;
        final d = view.debt;
        final reps = cubit.repaymentsFor(debtId);

        return Scaffold(
          appBar: AppBar(
            title: Text(d.counterparty),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showDebtEditor(context, existing: d),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') _confirmDelete(context, d);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              _Header(view: view),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Échéancier de remboursement',
                        style: Theme.of(context).textTheme.titleSmall),
                    TextButton.icon(
                      onPressed: () => _addRepayment(context, d),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Échéance'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: reps.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Aucune échéance planifiée.\nAjoute des remboursements aux dates que tu choisis.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: reps.length,
                        itemBuilder: (context, i) =>
                            _RepaymentTile(repayment: reps[i], debt: d),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addRepayment(BuildContext context, Debt d) async {
    final cubit = context.read<DebtsCubit>();
    final ctrl = TextEditingController();
    DateTime date = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nouvelle échéance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Montant',
                  suffixText: MoneyFormatter.appSymbol,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: Text(DateFormat('d MMM yyyy', 'fr_FR').format(date)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2015),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setLocal(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final amount = MoneyFormatter.parseToMinor(ctrl.text);
      if (amount > 0) await cubit.addRepayment(d, dueDate: date, amount: amount);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Debt d) async {
    final cubit = context.read<DebtsCubit>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la dette ?'),
        content: Text(
            'La dette « ${d.counterparty} » et ses échéances seront supprimées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await cubit.deleteDebt(d.id);
      nav.pop();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.view});
  final DebtView view;

  @override
  Widget build(BuildContext context) {
    final d = view.debt;
    final progress = d.principal <= 0
        ? 0.0
        : ((d.principal - view.remaining) / d.principal).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.direction == DebtDirection.iOwe ? 'Je dois' : 'On me doit',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (d.reason != null && d.reason!.isNotEmpty)
            Text(d.reason!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  'Remboursé ${MoneyFormatter.format(d.principal - view.remaining)}'),
              Text('Reste ${MoneyFormatter.format(view.remaining)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RepaymentTile extends StatelessWidget {
  const _RepaymentTile({required this.repayment, required this.debt});
  final DebtRepayment repayment;
  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DebtsCubit>();
    final paid = repayment.status == RepaymentStatus.paid;
    final today = DateTime.now();
    final overdue = !paid &&
        repayment.dueDate.isBefore(DateTime(today.year, today.month, today.day));

    return Dismissible(
      key: ValueKey(repayment.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: AppTheme.expense,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => cubit.deleteRepayment(repayment),
      child: ListTile(
        leading: Icon(
          paid ? Icons.check_circle : Icons.schedule,
          color: paid
              ? AppTheme.budgetOk
              : (overdue ? AppTheme.expense : null),
        ),
        title: Text(MoneyFormatter.format(repayment.amount)),
        subtitle: Text(
          DateFormat('EEEE d MMM yyyy', 'fr_FR').format(repayment.dueDate),
          style: overdue
              ? const TextStyle(color: AppTheme.expense)
              : null,
        ),
        trailing: Checkbox(
          value: paid,
          onChanged: (v) {
            if (v == true) {
              cubit.markPaid(repayment);
            } else {
              cubit.markUnpaid(repayment);
            }
          },
        ),
      ),
    );
  }
}
