import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/premium/premium_cubit.dart';
import 'premium_page.dart';

/// Ouvre l'écran de paywall pour la fonctionnalité [feature].
Future<void> showPaywall(BuildContext context, {String? feature}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PremiumPage(feature: feature),
    ),
  );
}

/// Vérifie l'accès premium. Si l'utilisateur est premium, retourne `true`
/// immédiatement. Sinon affiche le paywall et retourne `true` seulement si
/// l'utilisateur est devenu premium entre-temps (achat/restauration réussis).
///
/// Usage typique dans un `onPressed` :
/// ```dart
/// if (await requirePremium(context, feature: 'Prévisions')) {
///   // ... action premium
/// }
/// ```
Future<bool> requirePremium(BuildContext context, {String? feature}) async {
  final cubit = context.read<PremiumCubit>();
  if (cubit.isPremium) return true;
  await showPaywall(context, feature: feature);
  if (!context.mounted) return false;
  return context.read<PremiumCubit>().isPremium;
}

/// Petit badge « Premium » (cadenas) à accoler à une entrée gatée.
class PremiumLockBadge extends StatelessWidget {
  const PremiumLockBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium,
              size: 13, color: cs.onPrimaryContainer),
          const SizedBox(width: 3),
          Text('Premium',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onPrimaryContainer,
              )),
        ],
      ),
    );
  }
}
