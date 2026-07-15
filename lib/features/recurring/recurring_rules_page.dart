import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/recurrence.dart';
import '../../core/utils/visuals.dart';
import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/recurring_rule.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import 'cubit/recurring_rules_cubit.dart';

class RecurringRulesPage extends StatelessWidget {
  const RecurringRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions récurrentes')),
      body: BlocBuilder<RecurringRulesCubit, RecurringRulesState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.rules.isEmpty) {
            return const _Empty();
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: state.rules.map((r) => _RuleTile(rule: r)).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRecurringEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Récurrence'),
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
            Icon(Icons.autorenew, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Aucune transaction récurrente.\nAutomatise ton salaire, ton loyer, tes abonnements...',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule});
  final RecurringRule rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = rule.type == TransactionType.income;
    final color = isIncome ? AppTheme.income : AppTheme.expense;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(isIncome ? Icons.south_west : Icons.north_east,
            color: color),
      ),
      title: Text(rule.label),
      subtitle: Text(
        '${frequencyLabel(rule.frequency)} • prochaine : ${DateFormat('d MMM yyyy', 'fr_FR').format(rule.nextRun)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(MoneyFormatter.formatSigned(rule.type == TransactionType.income
              ? rule.amount
              : -rule.amount),
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          if (!rule.active)
            Text('en pause', style: theme.textTheme.bodySmall),
        ],
      ),
      onTap: () => showRecurringEditor(context, existing: rule),
    );
  }
}

Future<void> showRecurringEditor(BuildContext context,
    {RecurringRule? existing}) {
  final cubit = context.read<RecurringRulesCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _RecurringEditor(existing: existing),
    ),
  );
}

class _RecurringEditor extends StatefulWidget {
  const _RecurringEditor({this.existing});
  final RecurringRule? existing;

  @override
  State<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<_RecurringEditor> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _accountId;
  RecurrenceFrequency _freq = RecurrenceFrequency.monthly;
  late DateTime _startDate;
  bool _active = true;

  List<Category> get _categories => sl<CategoryRepository>().byKind(
        _type == TransactionType.expense
            ? CategoryKind.expense
            : CategoryKind.income,
      );
  List<Account> get _accounts => sl<AccountRepository>().getActive();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _startDate = e?.startDate ?? DateTime.now();
    if (e != null) {
      _labelCtrl.text = e.label;
      _amountCtrl.text = MoneyFormatter.toInput(e.amount);
      _type = e.type;
      _categoryId = e.categoryId;
      _accountId = e.accountId;
      _freq = e.frequency;
      _active = e.active;
    } else {
      _accountId = _accounts.isEmpty ? null : _accounts.first.id;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) return;
    final cubit = context.read<RecurringRulesCubit>();
    final amount = MoneyFormatter.parseToMinor(_amountCtrl.text);
    if (widget.existing == null) {
      await cubit.addRule(
        label: _labelCtrl.text,
        amount: amount,
        type: _type,
        accountId: _accountId!,
        categoryId: _categoryId,
        frequency: _freq,
        startDate: _startDate,
      );
    } else {
      final e = widget.existing!
        ..label = _labelCtrl.text.trim()
        ..amount = amount
        ..type = _type
        ..accountId = _accountId!
        ..categoryId = _categoryId
        ..frequency = _freq
        ..active = _active;
      await cubit.updateRule(e);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        isEdit ? 'Modifier la récurrence' : 'Nouvelle récurrence',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  if (isEdit)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await context
                            .read<RecurringRulesCubit>()
                            .deleteRule(widget.existing!.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Dépense'),
                      icon: Icon(Icons.remove_circle_outline)),
                  ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Revenu'),
                      icon: Icon(Icons.add_circle_outline)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  if (!_categories.any((c) => c.id == _categoryId)) {
                    _categoryId = null;
                  }
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Libellé',
                  hintText: 'Salaire, Loyer, Abonnement...',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Libellé requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Montant',
                  suffixText: MoneyFormatter.appSymbol,
                  prefixIcon: const Icon(Icons.tag),
                ),
                validator: (v) {
                  if (MoneyFormatter.parseToMinor(v ?? '') <= 0) {
                    return 'Entre un montant valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    _categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(children: [
                            Icon(c.icon, color: c.color, size: 20),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    _accounts.any((a) => a.id == _accountId) ? _accountId : null,
                decoration: const InputDecoration(
                  labelText: 'Compte',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: _accounts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Row(children: [
                            Icon(a.type.icon, size: 20),
                            const SizedBox(width: 8),
                            Text(a.name),
                          ]),
                        ))
                    .toList(),
                validator: (v) => v == null ? 'Choisis un compte' : null,
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurrenceFrequency>(
                initialValue: _freq,
                decoration: const InputDecoration(
                  labelText: 'Fréquence',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: RecurrenceFrequency.values
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(frequencyLabel(f)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _freq = v ?? RecurrenceFrequency.monthly),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickStart,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                    'Début : ${DateFormat('d MMM yyyy', 'fr_FR').format(_startDate)}'),
              ),
              if (isEdit)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text('Génère les transactions automatiquement'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              const SizedBox(height: 12),
              if (!isEdit)
                Text(
                  'La première transaction sera créée à la date de début, puis automatiquement à chaque échéance.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(isEdit ? 'Enregistrer' : 'Créer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
