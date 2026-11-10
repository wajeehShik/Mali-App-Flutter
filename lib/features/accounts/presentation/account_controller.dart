import '../../../core/errors/failure.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';

/// عمليات تعديل الحسابات مع حراسة صلاحية الكتابة.
///
/// [canWrite] يجب أن يقرأ الصلاحية الحالية من حالة التفعيل.
/// عندما تكون false، يمنع المتحكم أي تعديل حتى لو وصل الطلب من
/// مكان لا تحميه واجهة المستخدم أو حراسة الراوتر.
class AccountController {
  const AccountController({
    required AccountRepository repository,
    required bool Function() canWrite,
  })  : _repository = repository,
        _canWrite = canWrite;

  final AccountRepository _repository;
  final bool Function() _canWrite;

  Future<Failure?> create(Account account) async {
    final permissionFailure = _permissionFailure();
    if (permissionFailure != null) return permissionFailure;

    final result = await _repository.create(account);
    return result.failureOrNull;
  }

  Future<Failure?> update(Account account) async {
    final permissionFailure = _permissionFailure();
    if (permissionFailure != null) return permissionFailure;

    final result = await _repository.update(account);
    return result.failureOrNull;
  }

  Future<Failure?> archive(String id) async {
    final permissionFailure = _permissionFailure();
    if (permissionFailure != null) return permissionFailure;

    final result = await _repository.archive(id);
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
