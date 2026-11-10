import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/features/categories/domain/category.dart';
import 'package:mali/features/categories/domain/category_repository.dart';
import 'package:mali/features/categories/presentation/categories_screen.dart';
import 'package:mali/features/categories/presentation/category_controller.dart';
import 'package:mali/features/categories/presentation/category_providers.dart';

class _FakeCategoryRepository implements CategoryRepository {
  static const income = Category(
    id: 'income-1',
    name: 'دخل إضافي',
    kind: CategoryKind.income,
  );

  static const expense = Category(
    id: 'expense-1',
    name: 'مواصلات',
    kind: CategoryKind.expense,
  );

  static const product = Category(
    id: 'product-1',
    name: 'مشروبات',
    kind: CategoryKind.product,
  );

  Category? createdCategory;

  @override
  Stream<List<Category>> watchByKind(CategoryKind kind) {
    final category = switch (kind) {
      CategoryKind.income => income,
      CategoryKind.expense => expense,
      CategoryKind.product => product,
    };
    return Stream.value([category]);
  }

  @override
  Future<Result<List<Category>>> getAll() async =>
      const Ok([income, expense, product]);

  @override
  Future<Result<Category?>> getById(String id) async => const Ok(null);

  @override
  Future<Result<void>> create(Category category) async {
    createdCategory = category;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> update(Category category) async => const Ok<void>(null);

  @override
  Future<Result<void>> softDelete(String id) async => const Ok<void>(null);
}

void main() {
  late _FakeCategoryRepository repository;

  Future<void> pumpScreen(WidgetTester tester) async {
    repository = _FakeCategoryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(repository),
          categoryControllerProvider.overrideWithValue(
            CategoryController(
              repository: repository,
              canWrite: () => true,
            ),
          ),
        ],
        child: const MaterialApp(home: CategoriesScreen()),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('يعرض أنواع التصنيفات الثلاثة', (tester) async {
    await pumpScreen(tester);

    expect(find.text('الدخل'), findsOneWidget);
    expect(find.text('المصروف'), findsOneWidget);
    expect(find.text('المنتجات'), findsOneWidget);
    expect(find.text('دخل إضافي'), findsOneWidget);

    await tester.tap(find.text('المنتجات'));
    await tester.pumpAndSettle();

    expect(find.text('مشروبات'), findsOneWidget);
  });

  testWidgets('ينشئ تصنيفًا من تبويب الدخل', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('تصنيف جديد'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'مبيعات أخرى');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(repository.createdCategory, isNotNull);
    expect(repository.createdCategory!.name, 'مبيعات أخرى');
    expect(repository.createdCategory!.kind, CategoryKind.income);
  });
}
