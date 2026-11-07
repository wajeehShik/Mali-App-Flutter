import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/activation/domain/activation_state.dart';
import '../../features/activation/presentation/activation_screen.dart';
import '../widgets/placeholder_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

/// مفتاح المتنقل الجذري: المسارات التي تُفتح فوق قشرة التنقل السفلي تستخدمه.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// المسارات التي تبقى متاحة للقراءة عند انتهاء التصريح.
/// صفحات إنشاء العمليات أو تعديلها غير مدرجة هنا.
const Set<String> _expiredAllowedPaths = {
  AppRoutes.dashboard,
  AppRoutes.transactions,
  AppRoutes.reports,
  AppRoutes.more,
  AppRoutes.accounts,
  AppRoutes.products,
  AppRoutes.categories,
  AppRoutes.inventory,
  AppRoutes.customers,
  AppRoutes.suppliers,
  AppRoutes.backup,
};

/// يبني راوتر التطبيق.
///
/// [readActivationState] يقرأ آخر حالة تفعيل.
/// [refreshListenable] يُخبر GoRouter أن حالة التفعيل تغيّرت.
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
                builder: (context, state) => const PlaceholderScreen(
                  title: 'الرئيسية',
                  icon: Icons.dashboard_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                name: AppRouteNames.transactions,
                builder: (context, state) => const PlaceholderScreen(
                  title: 'المعاملات',
                  icon: Icons.receipt_long_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.pos,
                name: AppRouteNames.pos,
                builder: (context, state) => const PlaceholderScreen(
                  title: 'نقطة البيع',
                  icon: Icons.point_of_sale_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                name: AppRouteNames.reports,
                builder: (context, state) => const PlaceholderScreen(
                  title: 'التقارير',
                  icon: Icons.bar_chart_rounded,
                ),
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

      // شاشة التفعيل الفعلية.
      GoRoute(
        path: AppRoutes.activation,
        name: AppRouteNames.activation,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ActivationScreen(),
      ),

      // مسارات بشاشة كاملة فوق القشرة.
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
      _fullScreen(
        AppRoutes.inventory,
        AppRouteNames.inventory,
        'المخزون',
        Icons.warehouse_rounded,
      ),
      _fullScreen(
        AppRoutes.sales,
        AppRouteNames.sales,
        'المبيعات',
        Icons.sell_rounded,
      ),
      _fullScreen(
        AppRoutes.purchases,
        AppRouteNames.purchases,
        'المشتريات',
        Icons.shopping_cart_rounded,
      ),
      _fullScreen(
        AppRoutes.income,
        AppRouteNames.income,
        'الإيرادات',
        Icons.trending_up_rounded,
      ),
      _fullScreen(
        AppRoutes.expenses,
        AppRouteNames.expenses,
        'المصروفات',
        Icons.trending_down_rounded,
      ),
      _fullScreen(
        AppRoutes.debts,
        AppRouteNames.debts,
        'الديون',
        Icons.handshake_rounded,
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
      _fullScreen(
        AppRoutes.backup,
        AppRouteNames.backup,
        'النسخ الاحتياطي',
        Icons.backup_rounded,
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

/// مسار بشاشة كاملة يُفتح فوق القشرة (دون شريط التنقل السفلي).
GoRoute _fullScreen(String path, String name, String title, IconData icon) {
  return GoRoute(
    path: path,
    name: name,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => PlaceholderScreen(title: title, icon: icon),
  );
}
