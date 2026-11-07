import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/placeholder_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

/// مفتاح المتنقل الجذري: المسارات التي تُفتح فوق قشرة التنقل السفلي تستخدمه.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// يبني راوتر التطبيق.
/// الشاشات الحالية مؤقتة (PlaceholderScreen) حتى تُبنى كل ميزة.
GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.dashboard,
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

      // مسارات بشاشة كاملة فوق القشرة.
      _fullScreen(
        AppRoutes.activation,
        AppRouteNames.activation,
        'التفعيل',
        Icons.vpn_key_rounded,
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