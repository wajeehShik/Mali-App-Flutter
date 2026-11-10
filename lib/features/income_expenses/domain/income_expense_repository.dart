import '../../../core/errors/failure.dart';
import 'income_expense.dart';

abstract interface class IncomeExpenseRepository {
  /// يراقب الحركات حسب نوعها مع خيارات التصفية.
  /// تاريخ from مشمول، وتاريخ to غير مشمول.
  Stream<List<IncomeExpense>> watchByType(
    IncomeExpenseType type, {
    DateTime? from,
    DateTime? to,
    String? categoryId,
  });

  Future<Result<List<IncomeExpense>>> getAll();

  Future<Result<List<IncomeExpense>>> search(String query);

  /// يرجع null إذا لم توجد الحركة.
  Future<Result<IncomeExpense?>> getById(String id);

  /// ينشئ الحركة ويسجلها في outbox ذريًا.
  Future<Result<void>> create(IncomeExpense entry);

  /// يعدّل الحركة ويسجل التعديل في outbox ذريًا.
  Future<Result<void>> update(IncomeExpense entry);

  /// يحذف الحركة حذفًا ناعمًا ويسجل الحذف في outbox ذريًا.
  Future<Result<void>> softDelete(String id);
}
