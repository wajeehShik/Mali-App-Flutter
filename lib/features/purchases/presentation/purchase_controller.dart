import '../../../core/errors/failure.dart';
import '../domain/purchase.dart';
import '../domain/purchase_repository.dart';

/// عمليات إنشاء وتعديل وحذف المشتريات مع التحقق من صلاحية الكتابة.
class PurchaseController {
  const PurchaseController({
    required PurchaseRepository repository,
    required bool Function() canWrite,
  })  : _repository = repository,
        _canWrite = canWrite;

  final PurchaseRepository _repository;
  final bool Function() _canWrite;

  Future<Failure?> create(Purchase purchase) async {
    final permissionFailure = _permissionFailure();
    if (permissionFailure != null) return permissionFailure;

    final result = await _repository.create(purchase);
    return result.failureOrNull;
  }

  Future<Failure?> update(Purchase purchase) async {
    final permissionFailure = _permissionFailure();
    if (permissionFailure != null) return permissionFailure;

    final result = await _repository.update(purchase);
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
