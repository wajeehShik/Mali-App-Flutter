import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/activation/domain/activation_state.dart';
import '../../features/activation/presentation/activation_screen.dart';
import '../../features/debts/presentation/debts_screen.dart';
import '../../features/income_expenses/domain/income_expense.dart';
import '../../features/income_expenses/presentation/income_expenses_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/purchases/presentation/purchases_screen.dart';
import '../../features/backup/presentation/backup_screen.dart';

import '../../features/reports/presentation/dashboard_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../widgets/placeholder_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// المسارات المتاحة للقراءة بعد انتهاء التفعيل.
/// المبيعات ونقطة البيع غير مسموحتين بعد انتهاء التفعيل.
const Set<String> _expiredAllowedPaths = {
  AppRoutes.dashboard,
  AppRoutes.transactions,
  AppRoutes.reports,
  AppRoutes.more,
  AppRoutes.accounts,
  AppRoutes.products,
  AppRoutes.categories,
  AppRoutes.inventory,
  AppRoutes.income,
  AppRoutes.expenses,
  AppRoutes.purchases,
  AppRoutes.debts,
  AppRoutes.customers,
  AppRoutes.suppliers,
  AppRoutes.backup,
};

GoRouter createAppRouter({
  required ActivationState? Function() readActivationState,
  required Listenable refreshListenable,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.dashboard,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final activation = readActivationState();
      final path = state.uri.path;

      if (activation == null) {
        return path == AppRoutes.activation ? null : AppRoutes.activation;
      }

      if (activation is NotActivated || activation is ActivationPending) {
        return path == AppRoutes.activation ? null : AppRoutes.activation;
      }

      if (activation is ActivationActive) {
        return path == AppRoutes.activation ? AppRoutes.dashboard : null;
      }

      if (activation is ActivationExpired) {
        if (path == AppRoutes.activation ||
            _expiredAllowedPaths.contains(path)) {
          return null;
        }
        return AppRoutes.dashboard;
      }

      return AppRoutes.activation;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                name: AppRouteNames.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                name: AppRouteNames.transactions,
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.pos,
                name: AppRouteNames.pos,
                builder: (context, state) => const SalesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                name: AppRouteNames.reports,
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                name: AppRouteNames.more,
                builder: (context, state) => const PlaceholderScreen(
                  title: 'المزيد',
                  icon: Icons.menu_open_rounded,
                ),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.activation,
        name: AppRouteNames.activation,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ActivationScreen(),
      ),

      _fullScreen(
        AppRoutes.accounts,
        AppRouteNames.accounts,
        'الحسابات',
        Icons.account_balance_wallet_rounded,
      ),
      _fullScreen(
        AppRoutes.transfer,
        AppRouteNames.transfer,
        'تحويل بين الحسابات',
        Icons.swap_horiz_rounded,
      ),
      _fullScreen(
        AppRoutes.products,
        AppRouteNames.products,
        'المنتجات',
        Icons.inventory_2_rounded,
      ),
      _fullScreen(
        AppRoutes.categories,
        AppRouteNames.categories,
        'التصنيفات',
        Icons.category_rounded,
      ),

      GoRoute(
        path: AppRoutes.inventory,
        name: AppRouteNames.inventory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const InventoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.sales,
        name: AppRouteNames.sales,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SalesScreen(),
      ),
      GoRoute(
        path: AppRoutes.purchases,
        name: AppRouteNames.purchases,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PurchasesScreen(),
      ),
      GoRoute(
        path: AppRoutes.income,
        name: AppRouteNames.income,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const IncomeExpensesScreen(
          initialType: IncomeExpenseType.income,
        ),
      ),
      GoRoute(
        path: AppRoutes.expenses,
        name: AppRouteNames.expenses,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const IncomeExpensesScreen(
          initialType: IncomeExpenseType.expense,
        ),
      ),
      GoRoute(
        path: AppRoutes.debts,
        name: AppRouteNames.debts,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DebtsScreen(),
      ),

      _fullScreen(
        AppRoutes.customers,
        AppRouteNames.customers,
        'العملاء',
        Icons.people_rounded,
      ),
      _fullScreen(
        AppRoutes.suppliers,
        AppRouteNames.suppliers,
        'الموردون',
        Icons.local_shipping_rounded,
      ),
    GoRoute(
  path: AppRoutes.backup,
  name: AppRouteNames.backup,
  parentNavigatorKey: rootNavigatorKey,
  builder: (context, state) => const BackupScreen(),
),

      _fullScreen(
        AppRoutes.settings,
        AppRouteNames.settings,
        'الإعدادات',
        Icons.settings_rounded,
      ),
    ],
  );
}

/// مسار كامل الشاشة يُفتح فوق القشرة، دون شريط التنقل السفلي.
GoRoute _fullScreen(String path, String name, String title, IconData icon) {
  return GoRoute(
    path: path,
    name: name,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => PlaceholderScreen(
      title: title,
      icon: icon,
    ),
  );
}
