import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// قشرة التطبيق: شريط تنقل سفلي بخمس تبويبات، يحتفظ كل تبويب بحالته.
///
/// ترتيب التبويبات هنا يجب أن يطابق ترتيب الفروع (branches) في app_router.dart.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'الرئيسية',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: 'المعاملات',
    ),
    NavigationDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale_rounded),
      label: 'نقطة البيع',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart_rounded),
      label: 'التقارير',
    ),
    NavigationDestination(
      icon: Icon(Icons.menu_rounded),
      selectedIcon: Icon(Icons.menu_open_rounded),
      label: 'المزيد',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: _destinations,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            // الضغط على التبويب الحالي يعيده إلى صفحته الأولى.
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}