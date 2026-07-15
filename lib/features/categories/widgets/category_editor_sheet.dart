import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/visuals.dart';
import '../../../data/models/category.dart';
import '../cubit/categories_cubit.dart';

/// Palette proposée pour les catégories personnalisées.
const _kColors = <int>[
  0xFF2E7D32, 0xFF00838F, 0xFF1565C0, 0xFF5E35B1,
  0xFF8E24AA, 0xFFAD1457, 0xFFC62828, 0xFFEF6C00,
  0xFFF9A825, 0xFF6D4C41, 0xFF546E7A, 0xFF00695C,
];

/// Icônes proposées (codePoints Material). Reconstruites via materialIcon.
const _kIcons = <IconData>[
  Icons.shopping_cart, Icons.restaurant, Icons.local_cafe,
  Icons.directions_bus, Icons.local_gas_station, Icons.home,
  Icons.receipt_long, Icons.bolt, Icons.water_drop,
  Icons.local_hospital, Icons.school, Icons.sports_esports,
  Icons.checkroom, Icons.family_restroom, Icons.pets,
  Icons.fitness_center, Icons.phone_android, Icons.wifi,
  Icons.card_giftcard, Icons.savings, Icons.payments,
  Icons.storefront, Icons.work, Icons.more_horiz,
];

Future<void> showCategoryEditor(BuildContext context, {Category? existing}) {
  final cubit = context.read<CategoriesCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _CategoryEditorSheet(existing: existing),
    ),
  );
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet({this.existing});
  final Category? existing;

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  CategoryKind _kind = CategoryKind.expense;
  late int _iconCodePoint;
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _kind = e.kind;
      _iconCodePoint = e.iconCodePoint;
      _colorValue = e.colorValue;
    } else {
      _iconCodePoint = _kIcons.first.codePoint;
      _colorValue = _kColors.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<CategoriesCubit>();
    if (widget.existing == null) {
      await cubit.addCategory(
        name: _nameCtrl.text,
        kind: _kind,
        iconCodePoint: _iconCodePoint,
        colorValue: _colorValue,
      );
    } else {
      await cubit.updateCategory(
        widget.existing!,
        name: _nameCtrl.text,
        kind: _kind,
        iconCodePoint: _iconCodePoint,
        colorValue: _colorValue,
      );
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
                  CircleAvatar(
                    backgroundColor: Color(_colorValue),
                    child: Icon(materialIcon(_iconCodePoint),
                        color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Modifier la catégorie' : 'Nouvelle catégorie',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom de la catégorie',
                  hintText: 'Ex : Coiffure, Église, Data...',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              SegmentedButton<CategoryKind>(
                segments: const [
                  ButtonSegment(
                    value: CategoryKind.expense,
                    icon: Icon(Icons.south_west),
                    label: Text('Dépense'),
                  ),
                  ButtonSegment(
                    value: CategoryKind.income,
                    icon: Icon(Icons.north_east),
                    label: Text('Revenu'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Couleur',
                    style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _kColors.map((c) {
                  final selected = c == _colorValue;
                  return GestureDetector(
                    onTap: () => setState(() => _colorValue = c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Icône',
                    style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _kIcons.map((ic) {
                  final selected = ic.codePoint == _iconCodePoint;
                  return GestureDetector(
                    onTap: () => setState(() => _iconCodePoint = ic.codePoint),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? Color(_colorValue).withValues(alpha: 0.20)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(color: Color(_colorValue), width: 2)
                            : null,
                      ),
                      child: Icon(ic,
                          color: selected ? Color(_colorValue) : null),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(isEdit ? 'Enregistrer' : 'Créer la catégorie'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
