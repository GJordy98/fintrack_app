import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../transactions/cubit/transactions_cubit.dart';
import 'forecast_engine.dart';
import 'forecast_service.dart';

class ForecastPage extends StatefulWidget {
  const ForecastPage({super.key});

  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage> {
  int _horizon = 6; // mois
  final _priceCtrl = TextEditingController();
  AffordabilityResult? _affordability;

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  void _simulate(ForecastInputs inputs) {
    final price = MoneyFormatter.parseToMinor(_priceCtrl.text);
    if (price <= 0) {
      setState(() => _affordability = null);
      return;
    }
    setState(() {
      _affordability = ForecastEngine.canAfford(
        startBalance: inputs.startBalance,
        price: price,
        netMonthly: inputs.netMonthly,
        from: DateTime.now(),
        scheduled: inputs.scheduled,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prévisions')),
      // Recalcule dès que les transactions changent.
      body: BlocBuilder<TransactionsCubit, TransactionsState>(
        builder: (context, _) {
          final inputs = sl<ForecastService>().build(windowMonths: 3);
          final points = ForecastEngine.project(
            startBalance: inputs.startBalance,
            netMonthly: inputs.netMonthly,
            months: _horizon,
            from: DateTime.now(),
            scheduled: inputs.scheduled,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(inputs: inputs),
              const SizedBox(height: 16),
              _HorizonSelector(
                horizon: _horizon,
                onChanged: (h) => setState(() => _horizon = h),
              ),
              const SizedBox(height: 12),
              _ForecastChart(points: points),
              const SizedBox(height: 24),
              _PurchaseSimulator(
                controller: _priceCtrl,
                onSimulate: () => _simulate(inputs),
                result: _affordability,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.inputs});
  final ForecastInputs inputs;

  @override
  Widget build(BuildContext context) {
    final net = inputs.netMonthly;
    final netColor = net >= 0 ? AppTheme.income : AppTheme.expense;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Solde actuel', style: Theme.of(context).textTheme.labelLarge),
            Text(
              MoneyFormatter.format(inputs.startBalance),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            _row(context, 'Revenus moyens / mois',
                MoneyFormatter.format(inputs.avgMonthlyIncome), AppTheme.income),
            _row(context, 'Dépenses moyennes / mois',
                MoneyFormatter.format(inputs.avgMonthlyExpense),
                AppTheme.expense),
            _row(
              context,
              'Flux net / mois',
              MoneyFormatter.formatSigned(net),
              netColor,
              bold: true,
            ),
            const SizedBox(height: 4),
            Text(
              'Estimé sur les ${inputs.windowMonths} derniers mois.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _HorizonSelector extends StatelessWidget {
  const _HorizonSelector({required this.horizon, required this.onChanged});
  final int horizon;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 1, label: Text('1 m')),
        ButtonSegment(value: 3, label: Text('3 m')),
        ButtonSegment(value: 6, label: Text('6 m')),
        ButtonSegment(value: 12, label: Text('12 m')),
      ],
      selected: {horizon},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.points});
  final List<ForecastPoint> points;

  String _compact(num minorUnits) {
    final v = minorUnits / 100; // centimes -> unités
    final a = v.abs();
    if (a >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (a >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].balance.toDouble()),
    ];
    final minY = points.map((p) => p.balance).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.balance).reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs() * 0.15).clamp(1000, double.infinity);

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minY: (minY - pad).toDouble(),
          maxY: (maxY + pad).toDouble(),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) => Text(_compact(v),
                    style: theme.textTheme.bodySmall),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox();
                  // N'affiche pas tous les mois si l'horizon est long.
                  if (points.length > 7 && i % 2 != 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('MMM', 'fr_FR').format(points[i].date),
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: theme.colorScheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseSimulator extends StatelessWidget {
  const _PurchaseSimulator({
    required this.controller,
    required this.onSimulate,
    required this.result,
  });

  final TextEditingController controller;
  final VoidCallback onSimulate;
  final AffordabilityResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart_outlined),
                const SizedBox(width: 8),
                Text('Simulateur d\'achat',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text('Quand pourrai-je acheter… ?',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Prix',
                      suffixText: MoneyFormatter.appSymbol,
                      isDense: true,
                    ),
                    onSubmitted: (_) => onSimulate(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onSimulate,
                  child: const Text('Estimer'),
                ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 16),
              _resultBanner(context, result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultBanner(BuildContext context, AffordabilityResult r) {
    final theme = Theme.of(context);
    if (!r.reachable) {
      return _banner(
        context,
        icon: Icons.trending_down,
        color: AppTheme.expense,
        text:
            'Avec ton rythme actuel, cet achat n\'est pas atteignable. Réduis tes dépenses ou augmente tes revenus.',
      );
    }
    if (r.months == 0) {
      return _banner(
        context,
        icon: Icons.check_circle,
        color: AppTheme.income,
        text: 'Tu peux te l\'offrir dès maintenant ! 🎉',
      );
    }
    final date = DateFormat('MMMM yyyy', 'fr_FR').format(r.date!);
    return _banner(
      context,
      icon: Icons.event_available,
      color: theme.colorScheme.primary,
      text:
          'Atteignable dans ${r.months} mois, vers ${date[0].toUpperCase()}${date.substring(1)}.',
    );
  }

  Widget _banner(BuildContext context,
      {required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
