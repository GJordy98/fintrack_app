import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money_formatter.dart';
import '../../../data/models/goal.dart';
import '../cubit/goals_cubit.dart';

Future<void> showGoalEditor(BuildContext context, {Goal? existing}) {
  final cubit = context.read<GoalsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _GoalEditorSheet(existing: existing),
    ),
  );
}

class _GoalEditorSheet extends StatefulWidget {
  const _GoalEditorSheet({this.existing});
  final Goal? existing;

  @override
  State<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<_GoalEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _initialCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _targetCtrl.text = MoneyFormatter.toInput(e.targetAmount);
      _initialCtrl.text = MoneyFormatter.toInput(e.currentAmount);
      _targetDate = e.targetDate;
      if (e.monthlyContribution > 0) {
        _monthlyCtrl.text = MoneyFormatter.toInput(e.monthlyContribution);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _initialCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(now.year, now.month + 6),
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<GoalsCubit>();
    final target = MoneyFormatter.parseToMinor(_targetCtrl.text);
    final initial = MoneyFormatter.parseToMinor(_initialCtrl.text);
    final monthly = MoneyFormatter.parseToMinor(_monthlyCtrl.text);

    if (widget.existing == null) {
      await cubit.addGoal(
        name: _nameCtrl.text,
        targetAmount: target,
        targetDate: _targetDate,
        initialAmount: initial,
        monthlyContribution: monthly,
      );
    } else {
      final e = widget.existing!
        ..name = _nameCtrl.text.trim()
        ..targetAmount = target
        ..targetDate = _targetDate
        ..monthlyContribution = monthly;
      // Cohérence du statut si la cible change.
      if (e.currentAmount >= e.targetAmount) {
        e.status = GoalStatus.reached;
      } else if (e.status == GoalStatus.reached) {
        e.status = GoalStatus.inProgress;
      }
      await cubit.updateGoal(e);
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
              Text(
                isEdit ? 'Modifier l\'objectif' : 'Nouvel objectif',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'objectif',
                  hintText: 'Ex : Ordinateur, Voyage...',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Montant cible',
                  suffixText: MoneyFormatter.appSymbol,
                  prefixIcon: const Icon(Icons.savings_outlined),
                ),
                validator: (v) {
                  if (MoneyFormatter.parseToMinor(v ?? '') <= 0) {
                    return 'Entre un montant valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _initialCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [MoneyInputFormatter()],
                enabled: !isEdit,
                decoration: InputDecoration(
                  labelText: isEdit
                      ? 'Déjà épargné'
                      : 'Déjà épargné (optionnel)',
                  suffixText: MoneyFormatter.appSymbol,
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _targetDate == null
                      ? 'Date cible (optionnelle)'
                      : 'Cible : ${DateFormat('d MMM yyyy', 'fr_FR').format(_targetDate!)}',
                ),
              ),
              if (_targetDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _targetDate = null),
                    child: const Text('Retirer la date'),
                  ),
                ),
              if (_targetDate == null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _monthlyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [MoneyInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Épargne mensuelle prévue (optionnel)',
                    helperText:
                        'Réservée chaque mois dans ton budget journalier',
                    suffixText: MoneyFormatter.appSymbol,
                    prefixIcon: const Icon(Icons.savings_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(isEdit ? 'Enregistrer' : 'Créer l\'objectif'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
