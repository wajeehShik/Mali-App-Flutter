import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/categories/domain/category.dart';
import 'package:mali/features/categories/domain/category_repository.dart';
import 'package:mali/features/categories/presentation/category_providers.dart';
import 'package:mali/features/products/domain/product.dart';
import 'package:mali/features/products/domain/product_repository.dart';
import 'package:mali/features/products/presentation/product_controller.dart';
import 'package:mali/features/products/presentation/product_providers.dart';
import 'package:mali/features/products/presentation/products_screen.dart';

class _FakeCategoryRepository implements CategoryRepository {
  @override
  Stream<List<Category>> watchByKind(CategoryKind kind) =>
      const Stream.empty();

  @override
  Future<Result<List<Category>>> getAll() async => const Ok([]);

  @override
  Future<Result<Category?>> getById(String id) async => const Ok(null);

  @override
  Future<Result<void>> create(Category category) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> update(Category category) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> softDelete(String id) async =>
      const Ok<void>(null);
}

class _FakeProductRepository implements ProductRepository {
  List<Product> products = [
    const Product(
      id: 'product-1',
      name: 'قهوة',
      barcode: '123456',
      salePrice: Money(2500),
      costPrice: Money(1800),
      minStock: 1500,
    ),
  ];

  Product? createdProduct;

  @override
  Stream<List<Product>> watchActive({String? categoryId}) =>
      Stream.value(products.where((product) => product.isActive).toList());

  @override
  Future<Result<List<Product>>> getAll() async => Ok(products);

  @override
  Future<Result<List<Product>>> search(String query) async => Ok(products);

  @override
  Future<Result<Product?>> getByBarcode(String barcode) async =>
      const Ok(null);

  @override
  Future<Result<Product?>> getById(String id) async => const Ok(null);

  @override
  Future<Result<void>> create(Product product) async {
    createdProduct = product;
    products = [...products, product];
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> update(Product product) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> setActive(String id, bool isActive) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> softDelete(String id) async =>
      const Ok<void>(null);
}

void main() {
  late _FakeProductRepository products;

  Future<void> pumpScreen(WidgetTester tester) async {
    products = _FakeProductRepository();
    final categories = _FakeCategoryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(categories),
          productRepositoryProvider.overrideWithValue(products),
          productControllerProvider.overrideWithValue(
            ProductController(
              repository: products,
              canWrite: () => true,
            ),
          ),
        ],
        child: const MaterialApp(home: ProductsScreen()),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('يعرض المنتجات ويبحث بالاسم أو الباركود', (tester) async {
    await pumpScreen(tester);

    expect(find.text('المنتجات'), findsOneWidget);
    expect(find.text('قهوة'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '123');
    await tester.pumpAndSettle();
    expect(find.text('قهوة'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نتائج مطابقة.'), findsOneWidget);
  });

  testWidgets('ينشئ منتجًا ويحوّل الأسعار وحد المخزون إلى قيم صحيحة',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('منتج جديد'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'شاي');
    await tester.enterText(fields.at(3), '12.50');
    await tester.enterText(fields.at(4), '8.25');
    await tester.enterText(fields.at(5), '1.500');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(products.createdProduct, isNotNull);
    expect(products.createdProduct!.name, 'شاي');
    expect(products.createdProduct!.salePrice, const Money(1250));
    expect(products.createdProduct!.costPrice, const Money(825));
    expect(products.createdProduct!.minStock, 1500);
  });
}
