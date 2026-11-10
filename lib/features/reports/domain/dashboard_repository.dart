import 'dashboard_summary.dart';

/// عقد قراءة ملخص لوحة التحكم المشتق من سجل المعاملات.
abstract interface class DashboardRepository {
  /// يراقب الملخص المالي، ويتحدث عند إضافة أو تعديل أو حذف معاملة.
  Stream<DashboardSummary> watchSummary();
}
