import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/premium/premium_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../data/models/goal.dart';
import '../feedback/goal_feedback_screen.dart';
import '../premium/premium_gate.dart';
import 'cubit/goals_cubit.dart';
import 'widgets/goal_editor_sheet.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  /// Ouvre l'éditeur d'objectif ; au-delà du quota gratuit, passe par le paywall.
  Future<void> _addGoal(BuildContext context) async {
    final overQuota = context.read<GoalsCubit>().state.goals.length >=
        PremiumConfig.freeGoalLimit;
    if (overQuota &&
        !await requirePremium(context, feature: 'Objectifs illimités')) {
      return;
    }
    if (context.mounted) showGoalEditor(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Objectifs')),
      body: BlocBuilder<GoalsCubit, GoalsState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.goals.isEmpty) {
            return const _EmptyGoals();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: state.goals.map((v) => _GoalCard(view: v)).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addGoal(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel objectif'),
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Aucun objectif pour l\'instant.\nAppuie sur « Nouvel objectif » pour commencer à épargner.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.view});
  final GoalView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = view.goal;
    final color = goal.colorValue != null
        ? Color(goal.colorValue!)
        : theme.colorScheme.primary;
    final reached = goal.status == GoalStatus.reached;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(
                    reached ? Icons.emoji_events : Icons.flag,
                    color: reached ? AppTheme.budgetWarn : color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name, style: theme.textTheme.titleMedium),
                      if (goal.targetDate != null)
                        Text(
                          'Cible : ${DateFormat('d MMM yyyy', 'fr_FR').format(goal.targetDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') {
                      showGoalEditor(context, existing: goal);
                    } else if (v == 'delete') {
                      _confirmDelete(context, goal);
                    } else if (v == 'replay') {
                      GoalFeedbackScreen.show(
                        context,
                        goal: goal,
                        status: goal.status,
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    if (goal.status != GoalStatus.inProgress)
                      const PopupMenuItem(
                          value: 'replay',
                          child: Text('Revoir l\'animation')),
                    const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 10,
                color: reached ? AppTheme.budgetOk : color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${MoneyFormatter.format(goal.currentAmount)} / ${MoneyFormatter.format(goal.targetAmount)}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text('${(goal.progress * 100).round()} %',
                    style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            if (reached)
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppTheme.budgetOk, size: 18),
                  const SizedBox(width: 6),
                  Text('Objectif atteint 🎉',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppTheme.budgetOk)),
                ],
              )
            else if (view.monthlyNeeded > 0)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.savings_outlined, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Épargne ${MoneyFormatter.format(view.monthlyNeeded)} / mois pour tenir la date',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text('Reste ${MoneyFormatter.format(goal.remaining)}',
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => _contribute(context, goal),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Verser'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _contribute(BuildContext context, Goal goal) async {
    final cubit = context.read<GoalsCubit>();
    final ctrl = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Verser vers « ${goal.name} »'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [MoneyInputFormatter()],
          decoration: InputDecoration(
            labelText: 'Montant',
            suffixText: MoneyFormatter.appSymbol,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, MoneyFormatter.parseToMinor(ctrl.text)),
            child: const Text('Verser'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0) {
      await cubit.contribute(goal, amount);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Goal goal) async {
    final cubit = context.read<GoalsCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'objectif ?'),
        content: Text('« ${goal.name} » sera supprimé.'),
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
    if (ok == true) await cubit.deleteGoal(goal.id);
  }
}
