import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/outbox_table.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/features/categories/data/category_repository_impl.dart';
import 'package:mali/features/categories/domain/category.dart';

import '../../../core/database/database_test_helper.dart';

void main() {
  late AppDatabase db;
  late CategoryRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = CategoryRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  Category makeCategory({
    String id = 'category-1',
    String name = 'دخل آخر',
    CategoryKind kind = CategoryKind.income,
  }) {
    return Category(id: id, name: name, kind: kind);
  }

  group('create', () {
    test('ينشئ تصنيفًا ويسجل outbox ذريًا', () async {
      final result = await repository.create(makeCategory());

      expect(result.isOk, isTrue);
      final saved = await db.categoriesDao.getById('category-1');
      expect(saved?.name, 'دخل آخر');
      expect(saved?.kind.name, 'income');

      final outbox = await db.outboxDao.getPending();
      expect(outbox, hasLength(1));
      expect(outbox.single.entity, 'categories');
      expect(outbox.single.entityId, 'category-1');
      expect(outbox.single.operation, OutboxOperation.create);
    });

    test('يرفض الاسم الفارغ', () async {
      final result = await repository.create(makeCategory(name: '  '));

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(await db.categoriesDao.getById('category-1'), isNull);
      expect(await db.outboxDao.getPending(), isEmpty);
    });
  });

  test('watchByKind يعيد التصنيفات من النوع المطلوب فقط', () async {
    await repository.create(makeCategory(id: 'income-1'));
    await repository.create(
      makeCategory(
        id: 'product-1',
        name: 'مواد غذائية',
        kind: CategoryKind.product,
      ),
    );

    final income = await repository.watchByKind(CategoryKind.income).first;
    final products = await repository.watchByKind(CategoryKind.product).first;

    expect(income.map((category) => category.id), ['income-1']);
    expect(products.map((category) => category.id), ['product-1']);
  });

  test('يعدّل التصنيف ويضيف حدث update إلى outbox', () async {
    await repository.create(makeCategory());

    final result = await repository.update(
      makeCategory(name: 'إيرادات إضافية'),
    );

    expect(result.isOk, isTrue);
    expect(
      (await db.categoriesDao.getById('category-1'))?.name,
      'إيرادات إضافية',
    );

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(2));
    expect(outbox.last.operation, OutboxOperation.update);
  });

  test('يحذف التصنيف حذفًا ناعمًا ويسجل delete في outbox', () async {
    await repository.create(makeCategory());

    final result = await repository.softDelete('category-1');

    expect(result.isOk, isTrue);
    expect(await db.categoriesDao.getById('category-1'), isNull);

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(2));
    expect(outbox.last.operation, OutboxOperation.delete);
  });

  test('يرجع NotFound عند تعديل تصنيف غير موجود', () async {
    final result = await repository.update(makeCategory(id: 'missing'));

    expect(result.failureOrNull, isA<NotFoundFailure>());
    expect(await db.outboxDao.getPending(), isEmpty);
  });
}
