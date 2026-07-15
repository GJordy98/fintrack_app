import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/premium/premium_config.dart';
import '../../core/premium/premium_cubit.dart';

/// Écran « FinTrack Premium » (paywall). Accessible depuis le menu Plus, la
/// section Premium des paramètres, ou affiché quand on tente une action gatée.
class PremiumPage extends StatelessWidget {
  const PremiumPage({super.key, this.feature});

  /// Nom de la fonctionnalité qui a déclenché l'ouverture (optionnel), pour
  /// contextualiser le message d'accroche.
  final String? feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FinTrack Premium')),
      body: BlocBuilder<PremiumCubit, PremiumState>(
        builder: (context, state) {
          if (state.isPremium) {
            return _PremiumActiveView(feature: feature);
          }
          return _PaywallView(feature: feature, state: state);
        },
      ),
    );
  }
}

class _PaywallView extends StatelessWidget {
  const _PaywallView({required this.feature, required this.state});

  final String? feature;
  final PremiumState state;

  Future<void> _subscribe(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<PremiumCubit>().buy();
    if (!ok && context.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Abonnement momentanément indisponible. '
            'Réessaie depuis une version installée via le Play Store.',
          ),
        ),
      );
    }
  }

  Future<void> _restore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<PremiumCubit>().restore();
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Recherche de tes achats…')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.workspace_premium,
                size: 56, color: cs.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          feature == null
              ? 'Passe à Premium'
              : 'Débloque « $feature »',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Toute la gestion de ton argent reste gratuite. '
          'Premium débloque les outils avancés :',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        ...PremiumConfig.benefits.map((b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: cs.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(b, style: theme.textTheme.bodyLarge),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 28),
        Card(
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Abonnement',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(state.price,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed:
              state.purchasePending ? null : () => _subscribe(context),
          icon: state.purchasePending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_open),
          label: Text(state.purchasePending ? 'Traitement…' : 'S\'abonner'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _restore(context),
          child: const Text('Restaurer mes achats'),
        ),
        if (!state.storeAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Le magasin d\'applications n\'est pas disponible ici '
              '(émulateur ou build hors Play Store).',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'L\'abonnement se renouvelle automatiquement. Tu peux l\'annuler '
          'à tout moment depuis le Play Store.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _PremiumActiveView extends StatelessWidget {
  const _PremiumActiveView({this.feature});

  final String? feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text('Tu es Premium ✨',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Merci de soutenir FinTrack ! Toutes les fonctionnalités '
              'avancées sont débloquées.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (feature != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text('Accéder à « $feature »'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
