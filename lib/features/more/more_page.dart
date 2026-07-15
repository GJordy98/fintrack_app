import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/premium/premium_cubit.dart';
import '../../core/widgets/placeholder_view.dart';
import '../categories/categories_page.dart';
import '../contributions/contributions_page.dart';
import '../debts/debts_page.dart';
import '../forecast/forecast_page.dart';
import '../notifications/notifications_page.dart';
import '../premium/premium_gate.dart';
import '../premium/premium_page.dart';
import '../recurring/recurring_rules_page.dart';
import '../settings/settings_page.dart';
import '../stats/stats_page.dart';

/// Onglet « Plus » : accès aux modules secondaires qui ne méritent pas un
/// onglet dédié dans la barre de navigation.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  Future<void> _open(BuildContext context, _MoreItem item) async {
    // Fonctionnalité premium : passe par le paywall si pas encore débloqué.
    if (item.premiumFeature != null) {
      final ok = await requirePremium(context, feature: item.premiumFeature);
      if (!ok || !context.mounted) return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: item.pageBuilder ??
            (_) => Scaffold(
                  appBar: AppBar(title: Text(item.title)),
                  body: PlaceholderView(
                    icon: item.icon,
                    title: item.title,
                    subtitle: item.placeholderSubtitle,
                  ),
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItem>[
      _MoreItem(
        icon: Icons.groups_outlined,
        title: 'Cotisations (tontines)',
        subtitle: 'Jours où tu cotises et jours où tu perçois',
        placeholderSubtitle: '',
        pageBuilder: (_) => const ContributionsPage(),
      ),
      _MoreItem(
        icon: Icons.receipt_long_outlined,
        title: 'Dettes',
        subtitle: 'Ce que tu dois / ce qu\'on te doit',
        placeholderSubtitle: '',
        pageBuilder: (_) => const DebtsPage(),
      ),
      _MoreItem(
        icon: Icons.autorenew,
        title: 'Transactions récurrentes',
        subtitle: 'Salaire, loyer, abonnements automatiques',
        placeholderSubtitle: '',
        pageBuilder: (_) => const RecurringRulesPage(),
        premiumFeature: 'Transactions récurrentes',
      ),
      _MoreItem(
        icon: Icons.timeline_outlined,
        title: 'Prévisions',
        subtitle: 'Projection de solde et simulateur d\'achat',
        placeholderSubtitle: '',
        pageBuilder: (_) => const ForecastPage(),
        premiumFeature: 'Prévisions',
      ),
      _MoreItem(
        icon: Icons.notifications_outlined,
        title: 'Notifications',
        subtitle: 'Rappels de saisie, cotisations, dettes, budget',
        placeholderSubtitle: '',
        pageBuilder: (_) => const NotificationsPage(),
      ),
      _MoreItem(
        icon: Icons.bar_chart_outlined,
        title: 'Statistiques',
        subtitle: 'Répartition, taux d\'épargne, exports',
        placeholderSubtitle: '',
        pageBuilder: (_) => const StatsPage(),
      ),
      _MoreItem(
        icon: Icons.category_outlined,
        title: 'Catégories',
        subtitle: 'Personnalise tes catégories de dépenses et revenus',
        placeholderSubtitle: '',
        pageBuilder: (_) => const CategoriesPage(),
      ),
      _MoreItem(
        icon: Icons.workspace_premium_outlined,
        title: 'FinTrack Premium',
        subtitle: 'Débloque les outils avancés',
        placeholderSubtitle: '',
        pageBuilder: (_) => const PremiumPage(),
      ),
      _MoreItem(
        icon: Icons.settings_outlined,
        title: 'Paramètres',
        subtitle: 'Devise, thème',
        placeholderSubtitle: '',
        pageBuilder: (_) => const SettingsPage(),
      ),
    ];

    final isPremium = context.watch<PremiumCubit>().state.isPremium;

    return Scaffold(
      appBar: AppBar(title: const Text('Plus')),
      body: ListView(
        children: [
          ...items.map((item) {
            final locked = item.premiumFeature != null && !isPremium;
            return ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: locked
                  ? const PremiumLockBadge()
                  : const Icon(Icons.chevron_right),
              onTap: () => _open(context, item),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.placeholderSubtitle,
    this.pageBuilder,
    this.premiumFeature,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String placeholderSubtitle;

  /// Si fourni, ouvre ce vrai écran au lieu du placeholder.
  final WidgetBuilder? pageBuilder;

  /// Si non nul, l'entrée est réservée au premium (nom de la fonctionnalité
  /// affiché sur le paywall).
  final String? premiumFeature;
}
