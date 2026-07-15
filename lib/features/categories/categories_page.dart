import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/premium/premium_config.dart';
import '../../core/utils/visuals.dart';
import '../../data/models/category.dart';
import '../premium/premium_gate.dart';
import 'cubit/categories_cubit.dart';
import 'widgets/category_editor_sheet.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  /// Ouvre l'éditeur ; au-delà du quota gratuit de catégories perso, paywall.
  Future<void> _addCategory(BuildContext context) async {
    final overQuota = context.read<CategoriesCubit>().customCount >=
        PremiumConfig.freeCustomCategoryLimit;
    if (overQuota &&
        !await requirePremium(context, feature: 'Catégories illimitées')) {
      return;
    }
    if (context.mounted) showCategoryEditor(context);
  }

  Future<void> _confirmDelete(BuildContext context, Category c) async {
    final cubit = context.read<CategoriesCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text(
          '« ${c.name} » n\'apparaîtra plus dans les listes. Les transactions '
          'déjà enregistrées avec cette catégorie sont conservées.',
        ),
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
    if (ok == true) await cubit.archiveCategory(c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catégories')),
      body: BlocBuilder<CategoriesCubit, CategoriesState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
            children: [
              _QuotaBanner(customCount: state.customCount),
              _SectionHeader('Dépenses', Icons.south_west),
              ...state.expense.map((c) => _CategoryTile(
                    category: c,
                    onEdit: () => showCategoryEditor(context, existing: c),
                    onDelete: () => _confirmDelete(context, c),
                  )),
              _SectionHeader('Revenus', Icons.north_east),
              ...state.income.map((c) => _CategoryTile(
                    category: c,
                    onEdit: () => showCategoryEditor(context, existing: c),
                    onDelete: () => _confirmDelete(context, c),
                  )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCategory(context),
        icon: const Icon(Icons.add),
        label: const Text('Catégorie'),
      ),
    );
  }
}

class _QuotaBanner extends StatelessWidget {
  const _QuotaBanner({required this.customCount});
  final int customCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = PremiumConfig.freeCustomCategoryLimit;
    final reached = customCount >= limit;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Text(
        reached
            ? 'Tu as atteint la limite gratuite de $limit catégories '
                'personnalisées. Passe à Premium pour en créer autant que tu veux.'
            : 'Catégories personnalisées : $customCount / $limit '
                '(illimité avec Premium).',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: category.color,
        child: Icon(category.icon, color: Colors.white, size: 20),
      ),
      title: Text(category.name),
      subtitle: category.isCustom ? const Text('Personnalisée') : null,
      trailing: category.isCustom
          ? PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            )
          : null,
      onTap: category.isCustom ? onEdit : null,
    );
  }
}
