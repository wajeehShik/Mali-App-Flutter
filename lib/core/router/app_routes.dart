/// مسارات التطبيق وأسماؤها. المصدر الوحيد لها في المشروع.
abstract final class AppRoutes {
  // التفعيل
  static const String activation = '/activation';

  // التبويبات الرئيسية
  static const String dashboard = '/dashboard';
  static const String transactions = '/transactions';
  static const String pos = '/pos';
  static const String reports = '/reports';
  static const String more = '/more';

  // الحسابات والتحويلات
  static const String accounts = '/accounts';
  static const String transfer = '/accounts/transfer';

  // المنتجات والمخزون
  static const String products = '/products';
  static const String categories = '/products/categories';
  static const String inventory = '/inventory';

  // العمليات المالية
  static const String sales = '/sales';
  static const String purchases = '/purchases';
  static const String income = '/income';
  static const String expenses = '/expenses';

  // الديون وجهات الاتصال
  static const String debts = '/debts';
  static const String customers = '/contacts/customers';
  static const String suppliers = '/contacts/suppliers';

  // النظام
  static const String backup = '/backup';
  static const String settings = '/settings';
}

/// أسماء المسارات (تُستخدم مع context.goNamed / pushNamed).
abstract final class AppRouteNames {
  static const String activation = 'activation';
  static const String dashboard = 'dashboard';
  static const String transactions = 'transactions';
  static const String pos = 'pos';
  static const String reports = 'reports';
  static const String more = 'more';
  static const String accounts = 'accounts';
  static const String transfer = 'transfer';
  static const String products = 'products';
  static const String categories = 'categories';
  static const String inventory = 'inventory';
  static const String sales = 'sales';
  static const String purchases = 'purchases';
  static const String income = 'income';
  static const String expenses = 'expenses';
  static const String debts = 'debts';
  static const String customers = 'customers';
  static const String suppliers = 'suppliers';
  static const String backup = 'backup';
  static const String settings = 'settings';
} 