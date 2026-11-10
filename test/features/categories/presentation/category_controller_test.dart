import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/features/categories/domain/category.dart';
import 'package:mali/features/categories/domain/category_repository.dart';
import 'package:mali/features/categories/presentation/category_controller.dart';

class _FakeCategoryRepository implements CategoryRepository {
  int createCalls = 0;

  @override
  Stream<List<Category>> watchByKind(CategoryKind kind) => const Stream.empty();

  @override
  Future<Result<List<Category>>> getAll() async => const Ok([]);

  @override
  Future<Result<Category?>> getById(String id) async => const Ok(null);

  @override
  Future<Result<void>> create(Category category) async {
    createCalls++;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> update(Category category) async => const Ok<void>(null);

  @override
  Future<Result<void>> softDelete(String id) async => const Ok<void>(null);
}

void main() {
  const category = Category(
    id: 'category-1',
    name: 'مبيعات',
    kind: CategoryKind.product,
  );

  test('يمنع إنشاء تصنيف عند انتهاء التفعيل', () async {
    final repository = _FakeCategoryRepository();
    final controller = CategoryController(
      repository: repository,
      canWrite: () => false,
    );

    final failure = await controller.create(category);

    expect(failure, isA<ActivationFailure>());
    expect(repository.createCalls, 0);
  });
}
