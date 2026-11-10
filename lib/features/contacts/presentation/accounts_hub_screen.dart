import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';

class AccountsHubScreen extends StatelessWidget {
  const AccountsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإدارة')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('الحسابات'),
            subtitle: const Text('عرض الحسابات وأرصدتها وإدارتها'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push(AppRoutes.accounts),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: const Text('تحويل بين الحسابات'),
            subtitle: const Text('نقل مبلغ من حساب إلى آخر'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push(AppRoutes.transfer),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('العملاء والموردون'),
            subtitle: const Text('عرض وإدارة جهات الاتصال'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push(AppRoutes.customers),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('التصنيفات'),
            subtitle: const Text('تصنيفات الدخل والمصروف والمنتجات'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push(AppRoutes.categories),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.warehouse_outlined),
            title: const Text('المخزون'),
            subtitle: const Text('عرض الكميات الحالية والتنبيه للمخزون المنخفض'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push(AppRoutes.inventory),
          ),
        ],
      ),
    );
  }
}
