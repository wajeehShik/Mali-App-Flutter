import '../../../core/errors/failure.dart';
import '../domain/sale.dart';
import '../domain/sale_repository.dart';

/// عمليات إنشاء وتعديل وحذف المبيعات مع التحقق من صلاحية الكتابة.
class SaleController {
  const SaleController({
    required SaleRepository repository,
    required bool Function() canWrite,
  })  : _repository = repository,
        _canWrite = canWrite;

  final SaleRepository _repository;
  final bool Function() _canWrite;

  Future<Failure?> create(Sale sale) async {
    final permissionFailure = _permissionFailure();
    if (permissionFailure != null) return permissionFailure;

    final result = await _repository.create(sale);
    return result.failureOrNull;
  }

  Future<Failure?> update(Sale sale) async {
    final permissionFailure = _permissionFailure();
    if (permissionFailure != null) return permissionFailure;

    final result = await _repository.update(sale);
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
