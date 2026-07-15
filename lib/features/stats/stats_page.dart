import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/visuals.dart';
import '../premium/premium_gate.dart';
import 'cubit/stats_cubit.dart';
import 'export_service.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          BlocBuilder<StatsCubit, StatsState>(
            builder: (context, state) => PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share),
              enabled: !state.loading,
              onSelected: (v) => _export(context, state, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'csv', child: Text('Exporter en CSV')),
                PopupMenuItem(value: 'pdf', child: Text('Exporter en PDF')),
              ],
            ),
          ),
        ],
      ),
      body: BlocBuilder<StatsCubit, StatsState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _MonthSelector(state: state),
              _SummaryCard(state: state),
              const SizedBox(height: 16),
              _BreakdownSection(state: state),
              const SizedBox(height: 24),
              _TrendSection(state: state),
            ],
          );
        },
      ),
    );
  }

  Future<void> _export(
      BuildContext context, StatsState state, String kind) async {
    // L'export CSV/PDF est une fonctionnalité premium.
    if (!await requirePremium(context, feature: 'Export CSV / PDF')) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final txs = context.read<StatsCubit>().transactionsForMonth();
    if (txs.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Aucune transaction à exporter ce mois.')),
      );
      return;
    }
    final label = DateFormat('MMMM_yyyy', 'fr_FR')
        .format(DateTime(state.year, state.month));
    final service = sl<ExportService>();
    if (kind == 'csv') {
      await service.exportCsv(txs, label);
    } else {
      await service.exportPdf(txs, label,
          income: state.income, expense: state.expense);
    }
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.state});
  final StatsState state;

  @override
  Widget build(BuildContext context) {
    final date = DateTime(state.year, state.month);
    final label = DateFormat('MMMM yyyy', 'fr_FR').format(date);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final p = DateTime(state.year, state.month - 1);
            context.read<StatsCubit>().setMonth(p.year, p.month);
          },
        ),
        Text(label[0].toUpperCase() + label.substring(1),
            style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            final n = DateTime(state.year, state.month + 1);
            context.read<StatsCubit>().setMonth(n.year, n.month);
          },
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});
  final StatsState state;

  @override
  Widget build(BuildContext context) {
    final rate = (state.savingsRate * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: _stat(context, 'Revenus',
                        MoneyFormatter.format(state.income), AppTheme.income)),
                Expanded(
                    child: _stat(context, 'Dépenses',
                        MoneyFormatter.format(state.expense), AppTheme.expense)),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                    child: _stat(
                        context,
                        'Solde',
                        MoneyFormatter.formatSigned(state.net),
                        state.net >= 0 ? AppTheme.income : AppTheme.expense)),
                Expanded(
                    child: _stat(
                        context,
                        'Taux d\'épargne',
                        '$rate %',
                        rate >= 0 ? AppTheme.budgetOk : AppTheme.budgetOver)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.state});
  final StatsState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.breakdown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('Aucune dépense ce mois.',
              style: theme.textTheme.bodyMedium),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Répartition des dépenses',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              sections: state.breakdown.map((s) {
                final color = s.category != null
                    ? Color(s.category!.colorValue)
                    : theme.colorScheme.outline;
                return PieChartSectionData(
                  value: s.amount.toDouble(),
                  color: color,
                  title: '${(s.ratio * 100).round()}%',
                  radius: 60,
                  titleStyle: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...state.breakdown.map((s) {
          final color = s.category != null
              ? Color(s.category!.colorValue)
              : theme.colorScheme.outline;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 12, height: 12, color: color),
                const SizedBox(width: 8),
                if (s.category != null)
                  Icon(s.category!.icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(s.category?.name ?? 'Sans catégorie')),
                Text(MoneyFormatter.format(s.amount),
                    style: theme.textTheme.bodyMedium),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({required this.state});
  final StatsState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxV = state.series.fold<int>(1, (m, p) {
      final v = p.income > p.expense ? p.income : p.expense;
      return v > m ? v : m;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Revenus vs dépenses (6 mois)',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxV * 1.15,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= state.series.length) {
                        return const SizedBox();
                      }
                      final p = state.series[i];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('MMM', 'fr_FR')
                              .format(DateTime(p.year, p.month)),
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < state.series.length; i++)
                  BarChartGroupData(x: i, barsSpace: 2, barRods: [
                    BarChartRodData(
                        toY: state.series[i].income.toDouble(),
                        color: AppTheme.income,
                        width: 7,
                        borderRadius: BorderRadius.circular(2)),
                    BarChartRodData(
                        toY: state.series[i].expense.toDouble(),
                        color: AppTheme.expense,
                        width: 7,
                        borderRadius: BorderRadius.circular(2)),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(context, AppTheme.income, 'Revenus'),
            const SizedBox(width: 16),
            _legend(context, AppTheme.expense, 'Dépenses'),
          ],
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, Color color, String label) {
    return Row(children: [
      Container(width: 12, height: 12, color: color),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
