import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/categories_table.dart' as db_categories;
import 'package:mali/core/database/tables/outbox_table.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/products/data/product_repository_impl.dart';
import 'package:mali/features/products/domain/product.dart';

import '../../../core/database/database_test_helper.dart';

void main() {
  late AppDatabase db;
  late ProductRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = ProductRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addProductCategory({
    String id = 'product-category',
    db_categories.CategoryKind kind = db_categories.CategoryKind.product,
  }) async {
    await db.categoriesDao.insertCategory(
      CategoriesCompanion.insert(
        id: Value(id),
        name: 'مواد غذائية',
        kind: kind,
      ),
    );
  }

  Product makeProduct({
    String id = 'product-1',
    String name = 'قهوة',
    String? categoryId,
    String? barcode = '123456',
    String unit = 'كغ',
    Money salePrice = const Money(2500),
    Money costPrice = const Money(1800),
    int minStock = 1500,
    bool isActive = true,
  }) {
    return Product(
      id: id,
      name: name,
      categoryId: categoryId,
      barcode: barcode,
      unit: unit,
      salePrice: salePrice,
      costPrice: costPrice,
      minStock: minStock,
      isActive: isActive,
    );
  }

  test('ينشئ منتجًا ويحفظ الأسعار كأعداد صحيحة ويسجل outbox', () async {
    await addProductCategory();

    final result = await repository.create(
      makeProduct(categoryId: 'product-category'),
    );

    expect(result.isOk, isTrue);

    final savedResult = await repository.getById('product-1');
    final saved = savedResult.valueOrNull;
    expect(saved, isNotNull);
    expect(saved!.salePrice, const Money(2500));
    expect(saved.costPrice, const Money(1800));
    expect(saved.minStock, 1500);
    expect(saved.categoryId, 'product-category');

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(1));
    expect(outbox.single.entity, 'products');
    expect(outbox.single.operation, OutboxOperation.create);
  });

  test('يرفض سعرًا سالبًا دون كتابة', () async {
    final result = await repository.create(
      makeProduct(salePrice: const Money(-1)),
    );

    expect(result.failureOrNull, isA<ValidationFailure>());
    expect((await repository.getById('product-1')).valueOrNull, isNull);
    expect(await db.outboxDao.getPending(), isEmpty);
  });

  test('يرفض تصنيفًا من نوع غير المنتجات', () async {
    await addProductCategory(kind: db_categories.CategoryKind.expense);

    final result = await repository.create(
      makeProduct(categoryId: 'product-category'),
    );

    expect(result.failureOrNull, isA<ConflictFailure>());
    expect((await repository.getById('product-1')).valueOrNull, isNull);
    expect(await db.outboxDao.getPending(), isEmpty);
  });

  test('يبحث بالاسم والباركود ويجلب بالباركود', () async {
    await repository.create(makeProduct());

    expect((await repository.search('قهوة')).valueOrNull, hasLength(1));
    expect((await repository.search('123')).valueOrNull, hasLength(1));
    expect(
      (await repository.getByBarcode('123456')).valueOrNull?.id,
      'product-1',
    );
  });

  test('تعطيل المنتج يسجّل تحديثًا ويزيله من المراقبة النشطة', () async {
    await repository.create(makeProduct());

    final result = await repository.setActive('product-1', false);

    expect(result.isOk, isTrue);
    expect(
      (await repository.getById('product-1')).valueOrNull?.isActive,
      isFalse,
    );
    expect(await repository.watchActive().first, isEmpty);

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(2));
    expect(outbox.last.operation, OutboxOperation.update);
  });

  test('الحذف الناعم يخفي المنتج ويسجل delete في outbox', () async {
    await repository.create(makeProduct());

    final result = await repository.softDelete('product-1');

    expect(result.isOk, isTrue);
    expect((await repository.getById('product-1')).valueOrNull, isNull);
    expect(await repository.watchActive().first, isEmpty);

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(2));
    expect(outbox.last.operation, OutboxOperation.delete);
  });

  test('فشل outbox يلغي إنشاء المنتج', () async {
    await db.customStatement('''
      CREATE TRIGGER reject_product_outbox
      BEFORE INSERT ON outbox
      BEGIN
        SELECT RAISE(ABORT, 'outbox unavailable');
      END
    ''');

    final result = await repository.create(makeProduct());

    expect(result.isErr, isTrue);
    expect((await repository.getById('product-1')).valueOrNull, isNull);
    expect(await db.outboxDao.getPending(), isEmpty);
  });
}
