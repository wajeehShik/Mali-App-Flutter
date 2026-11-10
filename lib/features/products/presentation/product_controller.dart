import '../../../core/errors/failure.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

/// عمليات تعديل المنتجات مع التحقق من صلاحية الكتابة.
class ProductController {
  const ProductController({
    required ProductRepository repository,
    required bool Function() canWrite,
  })  : _repository = repository,
        _canWrite = canWrite;

  final ProductRepository _repository;
  final bool Function() _canWrite;

  Future<Failure?> create(Product product) async {
    final failure = _permissionFailure();
    if (failure != null) return failure;

    final result = await _repository.create(product);
    return result.failureOrNull;
  }

  Future<Failure?> update(Product product) async {
    final failure = _permissionFailure();
    if (failure != null) return failure;

    final result = await _repository.update(product);
    return result.failureOrNull;
  }

  Future<Failure?> setActive(String id, bool isActive) async {
    final failure = _permissionFailure();
    if (failure != null) return failure;

    final result = await _repository.setActive(id, isActive);
    return result.failureOrNull;
  }

  Future<Failure?> softDelete(String id) async {
    final failure = _permissionFailure();
    if (failure != null) return failure;

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
