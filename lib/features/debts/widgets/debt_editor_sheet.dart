import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/visuals.dart';
import '../../../data/models/account.dart';
import '../../../data/models/debt.dart';
import '../../../data/repositories/account_repository.dart';
import '../cubit/debts_cubit.dart';

Future<void> showDebtEditor(BuildContext context, {Debt? existing}) {
  final cubit = context.read<DebtsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _DebtEditorSheet(existing: existing),
    ),
  );
}

class _DebtEditorSheet extends StatefulWidget {
  const _DebtEditorSheet({this.existing});
  final Debt? existing;

  @override
  State<_DebtEditorSheet> createState() => _DebtEditorSheetState();
}

class _DebtEditorSheetState extends State<_DebtEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  DebtDirection _direction = DebtDirection.iOwe;
  String? _accountId;
  DateTime _date = DateTime.now();

  List<Account> get _accounts => sl<AccountRepository>().getActive();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _direction = e.direction;
      _nameCtrl.text = e.counterparty;
      _amountCtrl.text = MoneyFormatter.toInput(e.principal);
      _reasonCtrl.text = e.reason ?? '';
      _accountId = e.accountId;
      _date = e.contractedDate;
    }
    _accountId ??= _accounts.isEmpty ? null : _accounts.first.id;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<DebtsCubit>();
    final reason =
        _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim();
    if (widget.existing == null) {
      await cubit.addDebt(
        direction: _direction,
        counterparty: _nameCtrl.text,
        principal: MoneyFormatter.parseToMinor(_amountCtrl.text),
        reason: reason,
        contractedDate: _date,
        accountId: _accountId,
      );
    } else {
      final e = widget.existing!
        ..direction = _direction
        ..counterparty = _nameCtrl.text.trim()
        ..principal = MoneyFormatter.parseToMinor(_amountCtrl.text)
        ..reason = reason
        ..contractedDate = _date
        ..accountId = _accountId;
      await cubit.updateDebt(e);
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
              Text(isEdit ? 'Modifier la dette' : 'Nouvelle dette',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SegmentedButton<DebtDirection>(
                segments: const [
                  ButtonSegment(
                    value: DebtDirection.iOwe,
                    label: Text('Je dois'),
                    icon: Icon(Icons.call_made),
                  ),
                  ButtonSegment(
                    value: DebtDirection.owedToMe,
                    label: Text('On me doit'),
                    icon: Icon(Icons.call_received),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (s) => setState(() => _direction = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: _direction == DebtDirection.iOwe
                      ? 'À qui je dois'
                      : 'Qui me doit',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
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
              TextFormField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motif (optionnel)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Compte des remboursements',
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
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                    'Le : ${DateFormat('d MMM yyyy', 'fr_FR').format(_date)}'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(isEdit ? 'Enregistrer' : 'Créer la dette'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
