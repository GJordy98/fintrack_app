import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/di/service_locator.dart';
import '../../core/premium/premium_config.dart';
import '../../core/premium/premium_service.dart';
import '../../core/utils/money_formatter.dart';
import '../../data/models/goal.dart';
import '../../data/settings_service.dart';
import '../goals/widgets/goal_editor_sheet.dart';
import '../premium/premium_gate.dart';

/// Écran plein écran de feedback émotionnel à l'atteinte / échec d'un objectif
/// (module 3.6). Court, passable au tap, rejouable.
class GoalFeedbackScreen extends StatefulWidget {
  const GoalFeedbackScreen({
    super.key,
    required this.goal,
    required this.status,
    this.amountAtEvaluation,
    this.animate = true,
  });

  final Goal goal;
  final GoalStatus status;
  final int? amountAtEvaluation;

  /// Joue l'animation Lottie. Faux quand un compte gratuit a épuisé son quota
  /// mensuel d'animations : le feedback reste affiché, mais en version statique.
  final bool animate;

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static Future<void> show(
    BuildContext context, {
    required Goal goal,
    required GoalStatus status,
    int? amountAtEvaluation,
  }) {
    // Quota d'animations : illimité en premium, sinon 4 par mois. Au-delà, on
    // affiche le feedback sans l'animation Lottie.
    final premium = sl<PremiumService>().isPremium;
    final settings = sl<SettingsService>();
    final monthKey = _monthKey(DateTime.now());
    final animate = premium ||
        settings.animationsUsedThisMonth(monthKey) <
            PremiumConfig.freeAnimationsPerMonth;
    if (animate && !premium) {
      // Consomme un crédit (fire-and-forget).
      settings.recordAnimationShown(monthKey);
    }

    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondary) => GoalFeedbackScreen(
          goal: goal,
          status: status,
          amountAtEvaluation: amountAtEvaluation,
          animate: animate,
        ),
        transitionsBuilder: (context, anim, secondary, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<GoalFeedbackScreen> createState() => _GoalFeedbackScreenState();
}

class _GoalFeedbackScreenState extends State<GoalFeedbackScreen> {
  Timer? _autoClose;

  bool get _reached => widget.status == GoalStatus.reached;

  @override
  void initState() {
    super.initState();
    // La célébration se referme seule après quelques secondes ; l'écran
    // d'encouragement reste (il propose des actions).
    if (_reached) {
      _autoClose = Timer(const Duration(seconds: 6), _close);
    }
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  void _close() {
    _autoClose?.cancel();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.amountAtEvaluation ?? widget.goal.currentAmount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Palettes : célébration vive / encouragement apaisant.
    final bg = _reached
        ? (isDark ? const Color(0xFF0E3B24) : const Color(0xFFE6F5EC))
        : (isDark ? const Color(0xFF16303F) : const Color(0xFFE8F1F8));
    final accent =
        _reached ? const Color(0xFF1E8E5A) : const Color(0xFF3A7CA5);

    return GestureDetector(
      onTap: _reached ? _close : null,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.animate)
                  Lottie.asset(
                    _reached
                        ? 'assets/lottie/success.json'
                        : 'assets/lottie/encourage.json',
                    height: 240,
                    repeat: !_reached,
                  )
                else
                  _StaticFeedback(reached: _reached, accent: accent),
                const SizedBox(height: 8),
                Text(
                  _reached ? 'Bravo ! 🎉' : 'Tu y es presque 💪',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  _reached
                      ? 'Objectif « ${widget.goal.name} » atteint.\nTu as épargné ${MoneyFormatter.format(amount)} 👏'
                      : 'Tu n\'as pas encore atteint « ${widget.goal.name} », '
                          'mais ce n\'est pas grave : tu peux relancer cet objectif '
                          'en ajustant la date ou le montant.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                if (_reached)
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: accent),
                    onPressed: _close,
                    child: const Text('Super !'),
                  )
                else ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: accent),
                    onPressed: () async {
                      _autoClose?.cancel();
                      // L'écran est encore affiché : on ouvre l'éditeur
                      // au-dessus, puis on referme le feedback.
                      await showGoalEditor(context, existing: widget.goal);
                      _close();
                    },
                    icon: const Icon(Icons.tune),
                    label: const Text('Ajuster l\'objectif'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _close,
                    child: const Text('Plus tard'),
                  ),
                ],
                if (!widget.animate) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      _autoClose?.cancel();
                      showPaywall(context, feature: 'Animations illimitées');
                    },
                    icon: const Icon(Icons.workspace_premium, size: 18),
                    label: const Text('Animations illimitées avec Premium'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Version statique (sans Lottie) affichée quand le quota d'animations gratuit
/// du mois est épuisé.
class _StaticFeedback extends StatelessWidget {
  const _StaticFeedback({required this.reached, required this.accent});

  final bool reached;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              reached ? Icons.emoji_events : Icons.self_improvement,
              size: 120,
              color: accent,
            ),
            const SizedBox(height: 8),
            Text(reached ? '🎉' : '💪',
                style: const TextStyle(fontSize: 40)),
          ],
        ),
      ),
    );
  }
}
