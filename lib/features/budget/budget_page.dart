import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/visuals.dart';
import 'cubit/budgets_cubit.dart';
import 'widgets/budget_editor_sheet.dart';

class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  static DateTime _parseMonth(String m) {
    final parts = m.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: BlocBuilder<BudgetsCubit, BudgetsState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              _MonthSelector(month: state.month),
              _SummaryCard(state: state),
              Expanded(
                child: state.budgets.isEmpty
                    ? const _EmptyBudgets()
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 96),
                        children: state.budgets
                            .map((b) => _BudgetTile(view: b))
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBudgetEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Enveloppe'),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month});
  final String month;

  @override
  Widget build(BuildContext context) {
    final date = BudgetPage._parseMonth(month);
    final label = DateFormat('MMMM yyyy', 'fr_FR').format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prev = DateTime(date.year, date.month - 1);
              context.read<BudgetsCubit>().setMonth(BudgetsCubit.monthKey(prev));
            },
          ),
          Text(
            label[0].toUpperCase() + label.substring(1),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final next = DateTime(date.year, date.month + 1);
              context.read<BudgetsCubit>().setMonth(BudgetsCubit.monthKey(next));
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});
  final BudgetsState state;

  @override
  Widget build(BuildContext context) {
    if (state.budgets.isEmpty) return const SizedBox.shrink();
    final ratio = state.totalAllocated == 0
        ? 0.0
        : (state.totalSpent / state.totalAllocated).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dépensé ce mois',
                    style: Theme.of(context).textTheme.labelLarge),
                Text(
                  '${MoneyFormatter.format(state.totalSpent)} / ${MoneyFormatter.format(state.totalAllocated)}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio.toDouble(),
                minHeight: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.view});
  final BudgetView view;

  Color _color() {
    if (view.isOver) return AppTheme.budgetOver;
    if (view.isWarning) return AppTheme.budgetWarn;
    return AppTheme.budgetOk;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final category = view.category;
    return ListTile(
      onTap: () => showBudgetEditor(context, existing: view.budget),
      leading: CircleAvatar(
        backgroundColor: (category?.color ?? color).withValues(alpha: 0.15),
        child: Icon(category?.icon ?? Icons.category,
            color: category?.color ?? color),
      ),
      title: Text(category?.name ?? 'Catégorie'),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: view.ratio,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              view.isOver
                  ? 'Dépassé de ${MoneyFormatter.format(-view.remaining)}'
                  : 'Reste ${MoneyFormatter.format(view.remaining)}',
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
      trailing: Text(
        '${MoneyFormatter.format(view.spent)}\n/ ${MoneyFormatter.format(view.allocated)}',
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_outline,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Aucune enveloppe pour ce mois.\nAppuie sur « Enveloppe » pour en créer une.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
