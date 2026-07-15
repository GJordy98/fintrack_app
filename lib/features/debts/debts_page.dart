import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import 'cubit/debts_cubit.dart';
import 'debt_detail_page.dart';
import 'widgets/debt_editor_sheet.dart';

class DebtsPage extends StatelessWidget {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dettes')),
      body: BlocBuilder<DebtsCubit, DebtsState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.debts.isEmpty) {
            return const _Empty();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              _Totals(state: state),
              if (state.iOwe.isNotEmpty) ...[
                const _SectionHeader('Je dois'),
                ...state.iOwe.map((v) => _DebtCard(view: v)),
              ],
              if (state.owedToMe.isNotEmpty) ...[
                const _SectionHeader('On me doit'),
                ...state.owedToMe.map((v) => _DebtCard(view: v)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDebtEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Dette'),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Aucune dette.\nSuis ce que tu dois et ce qu\'on te doit, avec des remboursements à tes dates.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.state});
  final DebtsState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Text('Je dois'),
                  const SizedBox(height: 4),
                  Text(MoneyFormatter.format(state.totalIOwe),
                      style: const TextStyle(
                          color: AppTheme.expense,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(width: 1, height: 36, color: Theme.of(context).dividerColor),
            Expanded(
              child: Column(
                children: [
                  const Text('On me doit'),
                  const SizedBox(height: 4),
                  Text(MoneyFormatter.format(state.totalOwedToMe),
                      style: const TextStyle(
                          color: AppTheme.income,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.view});
  final DebtView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = view.debt;
    final settled = d.status.name == 'settled';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (settled ? AppTheme.budgetOk : theme.colorScheme.primary)
              .withValues(alpha: 0.15),
          child: Icon(
            settled ? Icons.check : Icons.person,
            color: settled ? AppTheme.budgetOk : theme.colorScheme.primary,
          ),
        ),
        title: Text(d.counterparty),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            if (settled)
              const Text('Soldée ✓', style: TextStyle(color: AppTheme.budgetOk))
            else ...[
              Text('Reste ${MoneyFormatter.format(view.remaining)}'),
              if (view.nextRepayment != null)
                Text(
                  'Prochaine échéance : ${DateFormat('d MMM', 'fr_FR').format(view.nextRepayment!.dueDate)}',
                  style: TextStyle(
                    color: view.hasOverdue
                        ? AppTheme.expense
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
        trailing: view.hasOverdue && !settled
            ? const Icon(Icons.warning_amber_rounded, color: AppTheme.budgetWarn)
            : const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DebtDetailPage(debtId: d.id)),
        ),
      ),
    );
  }
}
