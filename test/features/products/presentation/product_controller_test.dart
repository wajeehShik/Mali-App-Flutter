import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/features/products/domain/product.dart';
import 'package:mali/features/products/domain/product_repository.dart';
import 'package:mali/features/products/presentation/product_controller.dart';

class _FakeProductRepository implements ProductRepository {
  int createCalls = 0;

  @override
  Stream<List<Product>> watchActive({String? categoryId}) =>
      const Stream.empty();

  @override
  Future<Result<List<Product>>> getAll() async => const Ok([]);

  @override
  Future<Result<List<Product>>> search(String query) async => const Ok([]);

  @override
  Future<Result<Product?>> getByBarcode(String barcode) async => const Ok(null);

  @override
  Future<Result<Product?>> getById(String id) async => const Ok(null);

  @override
  Future<Result<void>> create(Product product) async {
    createCalls++;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> update(Product product) async => const Ok<void>(null);

  @override
  Future<Result<void>> setActive(String id, bool isActive) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> softDelete(String id) async => const Ok<void>(null);
}

void main() {
  const product = Product(id: 'product-1', name: 'قهوة');

  test('يمنع إنشاء منتج عند انتهاء التفعيل', () async {
    final repository = _FakeProductRepository();
    final controller = ProductController(
      repository: repository,
      canWrite: () => false,
    );

    final failure = await controller.create(product);

    expect(failure, isA<ActivationFailure>());
    expect(repository.createCalls, 0);
  });
}
