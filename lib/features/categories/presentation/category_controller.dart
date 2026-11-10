import '../../../core/errors/failure.dart';
import '../domain/category.dart';
import '../domain/category_repository.dart';

/// عمليات الكتابة على التصنيفات مع التحقق من صلاحية التفعيل.
class CategoryController {
  const CategoryController({
    required CategoryRepository repository,
    required bool Function() canWrite,
  })  : _repository = repository,
        _canWrite = canWrite;

  final CategoryRepository _repository;
  final bool Function() _canWrite;

  Future<Failure?> create(Category category) async {
    final failure = _permissionFailure();
    if (failure != null) return failure;

    final result = await _repository.create(category);
    return result.failureOrNull;
  }

  Future<Failure?> update(Category category) async {
    final failure = _permissionFailure();
    if (failure != null) return failure;

    final result = await _repository.update(category);
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
