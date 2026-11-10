import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/errors/failure.dart';
import '../../activation/presentation/activation_providers.dart';
import '../data/income_expense_repository_impl.dart';
import '../domain/income_expense.dart';
import '../domain/income_expense_repository.dart';
import 'income_expense_controller.dart';

/// مستودع الإيرادات والمصروفات المحلي.
final incomeExpenseRepositoryProvider =
    Provider<IncomeExpenseRepository>((ref) {
  return IncomeExpenseRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// متحكم إنشاء وتعديل وحذف الحركات مع التحقق من صلاحية الكتابة.
final incomeExpenseControllerProvider =
    Provider<IncomeExpenseController>((ref) {
  return IncomeExpenseController(
    repository: ref.watch(incomeExpenseRepositoryProvider),
    canWrite: () =>
        ref.read(activationControllerProvider).value?.canWrite ?? false,
  );
});

/// يراقب الحركات حسب النوع.
final incomeExpensesByTypeProvider =
    StreamProvider.family<List<IncomeExpense>, IncomeExpenseType>(
  (ref, type) {
    return ref.watch(incomeExpenseRepositoryProvider).watchByType(type);
  },
);

/// يبحث في الحركات حسب الملاحظة أو المعرّف.
final incomeExpenseSearchProvider =
    FutureProvider.family<Result<List<IncomeExpense>>, String>(
  (ref, query) {
    return ref.watch(incomeExpenseRepositoryProvider).search(query);
  },
);

/// يجلب جميع الإيرادات والمصروفات غير المحذوفة.
final allIncomeExpensesProvider =
    FutureProvider<Result<List<IncomeExpense>>>((ref) {
  return ref.watch(incomeExpenseRepositoryProvider).getAll();
});
