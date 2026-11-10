import '../../../core/errors/failure.dart';
import '../domain/income_expense.dart';
import '../domain/income_expense_repository.dart';

/// عمليات إنشاء وتعديل وحذف الإيرادات والمصروفات مع التحقق من صلاحية الكتابة.
class IncomeExpenseController {
  const IncomeExpenseController({
    required IncomeExpenseRepository repository,
    required bool Function() canWrite,
  })  : _repository = repository,
        _canWrite = canWrite;

  final IncomeExpenseRepository _repository;
  final bool Function() _canWrite;

  Future<Failure?> create(IncomeExpense entry) async {
    final permissionFailure = _permissionFailure();
    if (permissionFailure != null) return permissionFailure;

    final result = await _repository.create(entry);
    return result.failureOrNull;
  }

  Future<Failure?> update(IncomeExpense entry) async {
    final permissionFailure = _permissionFailure();
    if (permissionFailure != null) return permissionFailure;

    final result = await _repository.update(entry);
    return result.failureOrNull;
  }

  Future<Failure?> softDelete(String id) async {
    final permissionFailure = _permissionFailure();
    if (permissionFailure != null) return permissionFailure;

    final result = await _repository.softDelete(id);
    return result.failureOrNull;
  }

  Failure? _permissionFailure() {
    if (_canWrite()) return null;

    return const ActivationFailure(
      'انتهى التفعيل. يمكنك قراءة البيانات وتصديرها فقط.',
      reason: ActivationFailureReason.expired,
    );
  }
}
