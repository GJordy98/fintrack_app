import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import 'cubit/daily_plan_cubit.dart';
import 'cubit/fixed_charges_cubit.dart';
import 'cubit/income_cubit.dart';
import 'fixed_charges_page.dart';
import 'income_page.dart';

class PlanningPage extends StatelessWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning journalier'),
        actions: [
          IconButton(
            tooltip: 'Charges fixes',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () {
              final cubit = context.read<FixedChargesCubit>();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: const FixedChargesPage(),
                ),
              ));
            },
          ),
          IconButton(
            tooltip: 'Mes revenus',
            icon: const Icon(Icons.payments_outlined),
            onPressed: () {
              final incomeCubit = context.read<IncomeCubit>();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: incomeCubit,
                  child: const IncomePage(),
                ),
              ));
            },
          ),
        ],
      ),
      body: BlocBuilder<DailyPlanCubit, DailyPlanState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _TodayCard(state: state),
              _ProgressSection(state: state),
              _SummaryCard(state: state),
              _WeekdayHeader(),
              _CalendarGrid(state: state),
            ],
          );
        },
      ),
    );
  }
}

/// Progression des dépenses vs prévu, par semaine et par mois.
class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.state});
  final DailyPlanState state;

  @override
  Widget build(BuildContext context) {
    if (state.days.isEmpty || state.totalPlanned == 0) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final isCurrent = state.isCurrentMonth(now: now);

    // Mois affiché.
    final monthStart = DateTime(state.year, state.month, 1);
    final monthEnd = DateTime(state.year, state.month, state.daysInMonth);
    final monthPlanned = state.plannedInRange(monthStart, monthEnd);
    final monthSpent = isCurrent
        ? state.spentInRange(monthStart, monthEnd, now: now)
        : state.days
            .where((d) => d.settled)
            .fold(0, (s, d) => s + d.effectiveActual);
    final monthPlannedToDate =
        isCurrent ? state.plannedToDateInRange(monthStart, monthEnd, now: now) : monthPlanned;

    final widgets = <Widget>[];

    // Semaine courante (uniquement si on regarde le mois en cours).
    if (isCurrent) {
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final wPlanned = state.plannedInRange(weekStart, weekEnd);
      if (wPlanned > 0) {
        widgets.add(_ProgressCard(
          title: 'Cette semaine',
          planned: wPlanned,
          spent: state.spentInRange(weekStart, weekEnd, now: now),
          plannedToDate: state.plannedToDateInRange(weekStart, weekEnd, now: now),
          showPace: true,
        ));
      }
    }

    widgets.add(_ProgressCard(
      title: 'Ce mois',
      planned: monthPlanned,
      spent: monthSpent,
      plannedToDate: monthPlannedToDate,
      showPace: isCurrent,
    ));

    return Column(children: widgets);
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.planned,
    required this.spent,
    required this.plannedToDate,
    required this.showPace,
  });

  final String title;
  final int planned;
  final int spent;
  final int plannedToDate;
  final bool showPace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = planned <= 0 ? 0.0 : (spent / planned).clamp(0.0, 1.0);
    final pct = planned <= 0 ? 0 : ((spent / planned) * 100).round();
    final over = spent > planned;

    // Rythme : dépensé vs prévu jusqu'à aujourd'hui.
    final paceDelta = spent - plannedToDate; // >0 = en dépassement
    final Color barColor =
        over ? AppTheme.budgetOver : (paceDelta > 0 && showPace ? AppTheme.budgetWarn : AppTheme.budgetOk);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text('$pct %',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: barColor, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio.toDouble(),
                minHeight: 10,
                color: barColor,
                backgroundColor: barColor.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${MoneyFormatter.format(spent)} dépensé sur ${MoneyFormatter.format(planned)} prévu',
              style: theme.textTheme.bodySmall,
            ),
            if (showPace) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    paceDelta > 0 ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: paceDelta > 0 ? AppTheme.budgetOver : AppTheme.budgetOk,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      paceDelta > 0
                          ? 'En dépassement de ${MoneyFormatter.format(paceDelta)} par rapport au rythme prévu'
                          : paceDelta < 0
                              ? 'En avance : ${MoneyFormatter.format(-paceDelta)} de moins que prévu 👍'
                              : 'Pile dans les clous',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: paceDelta > 0
                            ? AppTheme.budgetOver
                            : AppTheme.budgetOk,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carte mise en avant pour le jour même : prévu vs dépensé + bilan du soir.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.state});
  final DailyPlanState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    // Ne s'affiche que si le mois affiché contient aujourd'hui.
    if (state.year != now.year || state.month != now.month) {
      return const SizedBox.shrink();
    }
    DayCell? today;
    for (final c in state.days) {
      if (c.date.day == now.day) {
        today = c;
        break;
      }
    }
    if (today == null) return const SizedBox.shrink();
    final cell = today;

    final spent = cell.effectiveActual;
    final planned = cell.planned;
    final over = spent > planned && planned > 0;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Aujourd\'hui',
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                if (cell.settled)
                  Text('Journée validée ✓',
                      style: TextStyle(
                          color: over ? AppTheme.budgetOver : AppTheme.budgetOk,
                          fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniStat(context, 'Prévu',
                      MoneyFormatter.format(planned)),
                ),
                Expanded(
                  child: _miniStat(
                    context,
                    cell.settled ? 'Dépensé' : 'Dépensé (à ce jour)',
                    MoneyFormatter.format(spent),
                    color: over ? AppTheme.budgetOver : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showDayPlanSheet(context, cell),
                icon: Icon(cell.settled ? Icons.edit : Icons.done_all),
                label: Text(cell.settled
                    ? 'Modifier le bilan du jour'
                    : 'Faire le bilan du soir'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value,
      {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});
  final DailyPlanState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthDate = DateTime(state.year, state.month);
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR').format(monthDate);
    final noIncome = state.monthlyIncome == 0;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    final prev = DateTime(state.year, state.month - 1);
                    context
                        .read<DailyPlanCubit>()
                        .setMonth(prev.year, prev.month);
                  },
                ),
                Text(
                  monthLabel[0].toUpperCase() + monthLabel.substring(1),
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    final next = DateTime(state.year, state.month + 1);
                    context
                        .read<DailyPlanCubit>()
                        .setMonth(next.year, next.month);
                  },
                ),
              ],
            ),
            if (noIncome)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Ajoute tes revenus (icône 💰 en haut) pour une suggestion de budget par jour.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              )
            else ...[
              _row(context, 'Revenu du mois',
                  MoneyFormatter.format(state.monthlyIncome)),
              if (state.monthlyFixed > 0)
                _row(context, 'Charges fixes',
                    '- ${MoneyFormatter.format(state.monthlyFixed)}'),
              if (state.savingsFromGoals > 0)
                _row(context, 'Épargne objectifs',
                    '- ${MoneyFormatter.format(state.savingsFromGoals)}'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Épargne libre'),
                  Row(
                    children: [
                      Text('- ${MoneyFormatter.format(state.savingsFree)}'),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit, size: 16),
                        onPressed: () => _editSavings(context),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              _row(
                context,
                'Disponible à dépenser',
                MoneyFormatter.format(state.disposableMonthly),
                bold: true,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text('Budget journalier suggéré',
                        style: theme.textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Text(
                      MoneyFormatter.format(state.suggestedDaily),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmAutoFill(context),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Remplir le mois avec cette suggestion'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Future<void> _editSavings(BuildContext context) async {
    final cubit = context.read<DailyPlanCubit>();
    final ctrl =
        TextEditingController(text: MoneyFormatter.toInput(state.savingsFree));
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Épargne mensuelle souhaitée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Montant que tu veux mettre de côté chaque mois, en plus de tes objectifs. Il sera réservé avant de calculer ton budget par jour.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [MoneyInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Épargne / mois',
                suffixText: MoneyFormatter.appSymbol,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, MoneyFormatter.parseToMinor(ctrl.text)),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (result != null) await cubit.setMonthlySavingsTarget(result);
  }

  Future<void> _confirmAutoFill(BuildContext context) async {
    final cubit = context.read<DailyPlanCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remplir le mois ?'),
        content: Text(
            'Chaque jour non encore validé sera prérempli avec ${MoneyFormatter.format(state.suggestedDaily)}. Tu pourras ajuster jour par jour.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remplir')),
        ],
      ),
    );
    if (ok == true) await cubit.autoFill();
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(d,
                        style: Theme.of(context).textTheme.labelSmall),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.state});
  final DailyPlanState state;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(state.year, state.month, 1);
    final leading = first.weekday - 1; // lundi = 0
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (final day in state.days) {
      cells.add(_DayCellWidget(cell: day));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 0.72,
        children: cells,
      ),
    );
  }
}

class _DayCellWidget extends StatelessWidget {
  const _DayCellWidget({required this.cell});
  final DayCell cell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final isToday = cell.date.year == today.year &&
        cell.date.month == today.month &&
        cell.date.day == today.day;

    Color? bg;
    Color? border;
    if (cell.settled) {
      final over = cell.effectiveActual > cell.planned;
      bg = (over ? AppTheme.budgetOver : AppTheme.budgetOk)
          .withValues(alpha: 0.15);
      border = over ? AppTheme.budgetOver : AppTheme.budgetOk;
    } else if (isToday) {
      border = theme.colorScheme.primary;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showDayPlanSheet(context, cell),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: border ?? theme.dividerColor,
            width: border != null ? 1.5 : 0.5,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${cell.date.day}',
                style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
            if (cell.planned > 0)
              Text(
                _compact(cell.planned),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (cell.settled)
              Icon(
                cell.effectiveActual > cell.planned
                    ? Icons.arrow_upward
                    : Icons.check,
                size: 12,
                color: cell.effectiveActual > cell.planned
                    ? AppTheme.budgetOver
                    : AppTheme.budgetOk,
              )
            else if (cell.note != null && cell.note!.isNotEmpty)
              const Icon(Icons.celebration, size: 12),
          ],
        ),
      ),
    );
  }

  String _compact(int minorUnits) {
    final v = minorUnits / 100; // centimes -> unités
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 0);
  }
}

/// Feuille de planification / bilan d'un jour.
Future<void> showDayPlanSheet(BuildContext context, DayCell cell) {
  final cubit = context.read<DailyPlanCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _DayPlanSheet(cell: cell),
    ),
  );
}

class _DayPlanSheet extends StatefulWidget {
  const _DayPlanSheet({required this.cell});
  final DayCell cell;

  @override
  State<_DayPlanSheet> createState() => _DayPlanSheetState();
}

class _DayPlanSheetState extends State<_DayPlanSheet> {
  late final TextEditingController _plannedCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _actualCtrl;

  @override
  void initState() {
    super.initState();
    final suggested = context.read<DailyPlanCubit>().state.suggestedDaily;
    final planned =
        widget.cell.planned > 0 ? widget.cell.planned : suggested;
    _plannedCtrl = TextEditingController(text: MoneyFormatter.toInput(planned));
    _noteCtrl = TextEditingController(text: widget.cell.note ?? '');
    _actualCtrl = TextEditingController(
      text: MoneyFormatter.toInput(
          widget.cell.reportedActual ?? widget.cell.actualFromTx),
    );
  }

  @override
  void dispose() {
    _plannedCtrl.dispose();
    _noteCtrl.dispose();
    _actualCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePlan() async {
    final planned = MoneyFormatter.parseToMinor(_plannedCtrl.text);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    await context.read<DailyPlanCubit>().setPlanned(widget.cell.date, planned,
        note: note);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _settle() async {
    final actual = MoneyFormatter.parseToMinor(_actualCtrl.text);
    // On enregistre d'abord le plan éventuellement modifié.
    final planned = MoneyFormatter.parseToMinor(_plannedCtrl.text);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final cubit = context.read<DailyPlanCubit>();
    await cubit.setPlanned(widget.cell.date, planned, note: note);
    final verdict = await cubit.reportActual(widget.cell.date, actual);
    if (mounted) {
      Navigator.pop(context);
      _showVerdict(context, verdict);
    }
  }

  Widget _dayProgress(BuildContext context) {
    final theme = Theme.of(context);
    final planned = widget.cell.planned;
    final spent = widget.cell.effectiveActual;
    final ratio = planned <= 0 ? 0.0 : (spent / planned).clamp(0.0, 1.0);
    final pct = planned <= 0 ? 0 : ((spent / planned) * 100).round();
    final over = spent > planned;
    final color = over ? AppTheme.budgetOver : AppTheme.budgetOk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Progression du jour', style: theme.textTheme.labelMedium),
            Text('$pct %',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio.toDouble(),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          over
              ? 'Dépassé de ${MoneyFormatter.format(spent - planned)}'
              : 'Il te reste ${MoneyFormatter.format(planned - spent)} sur ce jour',
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }

  void _showVerdict(BuildContext context, DayVerdict v) {
    final ok = v.withinBudget;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(ok ? Icons.emoji_events : Icons.trending_up,
            color: ok ? AppTheme.budgetOk : AppTheme.budgetWarn, size: 40),
        title: Text(ok ? 'Bravo ! 👏' : 'Petit dépassement'),
        content: Text(
          ok
              ? 'Tu as tenu ton budget du jour (${MoneyFormatter.format(v.actual)} sur ${MoneyFormatter.format(v.planned)}). Continue comme ça, ton épargne est en bonne voie !'
              : 'Tu as dépensé ${MoneyFormatter.format(v.delta)} de plus que prévu. '
                  'Pas de panique : pour tenir ton épargne, vise environ ${MoneyFormatter.format(v.suggestedNextDaily)} par jour sur les jours restants. 💪',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dateLabel =
        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(widget.cell.date);
    final isPastOrToday = !widget.cell.date.isAfter(
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(dateLabel[0].toUpperCase() + dateLabel.substring(1),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (widget.cell.planned > 0) _dayProgress(context),
            const SizedBox(height: 4),
            TextField(
              controller: _plannedCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [MoneyInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Budget prévu pour ce jour',
                suffixText: MoneyFormatter.appSymbol,
                prefixIcon: const Icon(Icons.savings_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (ex : Soirée, courses...)',
                prefixIcon: Icon(Icons.celebration_outlined),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _savePlan,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Enregistrer le budget prévu'),
            ),
            if (isPastOrToday) ...[
              const Divider(height: 32),
              Text('Bilan du soir',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Combien as-tu réellement dépensé ? (pré-rempli depuis tes transactions du jour)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _actualCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Dépensé réel',
                  suffixText: MoneyFormatter.appSymbol,
                  prefixIcon: const Icon(Icons.receipt_long_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _settle,
                icon: const Icon(Icons.done_all),
                label: const Text('Valider ma journée'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
