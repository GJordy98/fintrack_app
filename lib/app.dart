import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_constants.dart';
import 'core/di/service_locator.dart';
import 'core/logging/remote_log_uploader.dart';
import 'core/premium/premium_cubit.dart';
import 'core/premium/premium_service.dart';
import 'data/sync/sync_service.dart';
import 'core/money/currency_cubit.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/accounts/cubit/accounts_cubit.dart';
import 'features/budget/cubit/budgets_cubit.dart';
import 'features/categories/cubit/categories_cubit.dart';
import 'features/contributions/cubit/contributions_cubit.dart';
import 'features/debts/cubit/debts_cubit.dart';
import 'features/goals/cubit/goals_cubit.dart';
import 'features/lock/cubit/app_lock_cubit.dart';
import 'features/lock/lock_screen.dart';
import 'features/planning/cubit/daily_plan_cubit.dart';
import 'features/planning/cubit/fixed_charges_cubit.dart';
import 'features/planning/cubit/income_cubit.dart';
import 'features/recurring/cubit/recurring_rules_cubit.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'features/auth/cubit/auth_state.dart';
import 'features/shell/home_shell.dart';
import 'features/stats/cubit/stats_cubit.dart';
import 'features/transactions/cubit/transactions_cubit.dart';

class FinTrackApp extends StatelessWidget {
  const FinTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<ThemeCubit>()),
        BlocProvider.value(value: sl<AccountsCubit>()),
        BlocProvider.value(value: sl<TransactionsCubit>()),
        BlocProvider.value(value: sl<BudgetsCubit>()),
        BlocProvider.value(value: sl<GoalsCubit>()),
        BlocProvider.value(value: sl<ContributionsCubit>()),
        BlocProvider.value(value: sl<DebtsCubit>()),
        BlocProvider.value(value: sl<IncomeCubit>()),
        BlocProvider.value(value: sl<FixedChargesCubit>()),
        BlocProvider.value(value: sl<DailyPlanCubit>()),
        BlocProvider.value(value: sl<StatsCubit>()),
        BlocProvider.value(value: sl<RecurringRulesCubit>()),
        BlocProvider.value(value: sl<PremiumCubit>()),
        BlocProvider.value(value: sl<CategoriesCubit>()),
        BlocProvider.value(value: sl<CurrencyCubit>()),
        BlocProvider.value(value: sl<AppLockCubit>()),
        BlocProvider.value(value: sl<AuthCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            // Local-first : l'app s'ouvre directement, utilisable hors-ligne
            // sans compte. La connexion (Paramètres → Cloud) sert seulement à
            // lier les données au compte pour la sauvegarde/sync.
            home: const _AppLockGate(),
            // Déclenche une synchro non bloquante dès qu'un utilisateur est
            // connecté (démarrage à froid avec session restaurée, ou login).
            builder: (context, child) => BlocListener<AuthCubit, AuthState>(
              listenWhen: (prev, curr) => curr is Authenticated,
              listener: (_, _) {
                unawaited(sl<SyncService>().syncNow());
                // Applique un éventuel déblocage premium accordé à ce compte.
                unawaited(_refreshBackendPremium());
              },
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}

/// Affiche l'écran de verrouillage quand l'app est verrouillée, sinon le shell.
/// Verrouille automatiquement quand l'app passe en arrière-plan.
class _AppLockGate extends StatefulWidget {
  const _AppLockGate();

  @override
  State<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<_AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      context.read<AppLockCubit>().lockIfEnabled();
    } else if (state == AppLifecycleState.resumed) {
      // Sync non bloquante au retour au premier plan si connecté.
      if (context.read<AuthCubit>().state is Authenticated) {
        unawaited(sl<SyncService>().syncNow());
      }
      // Tente de vider la file de logs en attente (livraison quand le réseau
      // revient) — sans compte requis, invisible pour l'utilisatrice.
      unawaited(sl<RemoteLogUploader>().flush());
      // Réapplique un éventuel déblocage premium serveur au retour au premier plan.
      unawaited(_refreshBackendPremium());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppLockCubit, AppLockStatus>(
      builder: (context, status) {
        if (status == AppLockStatus.locked) {
          return const LockScreen();
        }
        return const HomeShell();
      },
    );
  }
}

/// Rafraîchit le déblocage premium accordé côté serveur (champ is_premium de
/// `/api/me/`). Silencieux si hors-ligne / non connecté.
Future<void> _refreshBackendPremium() async {
  final granted = await sl<SyncService>().fetchIsPremium();
  if (granted != null) {
    await sl<PremiumService>().setBackendGranted(granted);
  }
}

