import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/money/currency_cubit.dart';
import '../../data/repositories/goal_repository.dart';
import '../budget/budget_page.dart';
import '../dashboard/dashboard_page.dart';
import '../feedback/goal_feedback_screen.dart';
import '../goals/cubit/goals_cubit.dart';
import '../goals/goals_page.dart';
import '../more/more_page.dart';
import '../planning/planning_page.dart';
import '../transactions/transactions_page.dart';

/// Coquille principale : barre de navigation à 5 onglets.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    DashboardPage(),
    PlanningPage(),
    TransactionsPage(),
    BudgetPage(),
    GoalsPage(),
    MorePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPendingFeedback());
  }

  /// Affiche à l'ouverture les feedbacks non encore vus (objectif atteint /
  /// manqué), puis les marque comme acquittés (module 3.6).
  Future<void> _showPendingFeedback() async {
    // S'assure que les objectifs échus sont évalués avant de lire l'historique.
    await sl<GoalsCubit>().evaluateDueGoals();
    final repo = sl<GoalRepository>();
    final pending = repo.unacknowledgedHistory()
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final entry in pending) {
      final goal = repo.getById(entry.goalId);
      if (goal != null && mounted) {
        await GoalFeedbackScreen.show(
          context,
          goal: goal,
          status: entry.status,
          amountAtEvaluation: entry.amountAtEvaluation,
        );
      }
      await repo.acknowledgeHistory(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Quand la devise change, on force la reconstruction des pages (sous le
      // Navigator, donc sans casser la pile de navigation) pour reformater les
      // montants dans la devise sélectionnée.
      body: BlocBuilder<CurrencyCubit, String>(
        builder: (context, currencyCode) {
          return KeyedSubtree(
            key: ValueKey(currencyCode),
            child: IndexedStack(index: _index, children: _pages),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Planning',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_vert_outlined),
            selectedIcon: Icon(Icons.swap_vert),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Objectifs',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Plus',
          ),
        ],
      ),
    );
  }
}
