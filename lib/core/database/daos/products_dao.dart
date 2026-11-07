import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/products_table.dart';

part 'products_dao.g.dart';

/// وصول مباشر لجدول المنتجات. لا منطق أعمال هنا.
@DriftAccessor(tables: [Products])
class ProductsDao extends DatabaseAccessor<AppDatabase>
    with _$ProductsDaoMixin {
  ProductsDao(super.db);

  /// المنتجات النشطة غير المحذوفة، اختياريًا ضمن تصنيف، وتتحدث تلقائيًا.
  Stream<List<ProductRow>> watchActive({String? categoryId}) {
    final query = select(products)
      ..where((p) {
        var condition = p.deletedAt.isNull() & p.isActive.equals(true);
        if (categoryId != null) {
          condition = condition & p.categoryId.equals(categoryId);
        }
        return condition;
      })
      ..orderBy([(p) => OrderingTerm.asc(p.name)]);
    return query.watch();
  }

  /// كل المنتجات غير المحذوفة (بما فيها غير النشطة).
  Future<List<ProductRow>> getAll() {
    final query = select(products)
      ..where((p) => p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.name)]);
    return query.get();
  }

  /// بحث بالاسم أو الباركود في المنتجات النشطة.
  Future<List<ProductRow>> search(String text) {
    final pattern = '%${text.trim()}%';
    final query = select(products)
      ..where((p) =>
          p.deletedAt.isNull() &
          p.isActive.equals(true) &
          (p.name.like(pattern) | p.barcode.like(pattern)))
      ..orderBy([(p) => OrderingTerm.asc(p.name)]);
    return query.get();
  }

  /// جلب منتج نشط بالباركود (لنقطة البيع). null إن لم يوجد.
  Future<ProductRow?> getByBarcode(String barcode) {
    final query = select(products)
      ..where((p) =>
          p.deletedAt.isNull() &
          p.isActive.equals(true) &
          p.barcode.equals(barcode))
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<ProductRow?> getById(String id) {
    final query = select(products)
      ..where((p) => p.id.equals(id) & p.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  Future<void> insertProduct(ProductsCompanion entry) {
    return into(products).insert(entry);
  }

  /// يعدّل الحقول الممرَّرة فقط. يعيد true إن وُجد السجل.
  Future<bool> updateProduct(String id, ProductsCompanion changes) async {
    final count = await (update(products)
          ..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
        .write(
      changes.copyWith(
        updatedAt: Value(DateTime.now().toUtc()),
        syncStatus: const Value('pending'),
      ),
    );
    return count > 0;
  }

  /// حذف ناعم: يبقى السجل في القاعدة (وبنود العمليات القديمة تبقى سليمة).
  Future<bool> softDelete(String id) async {
    final now = DateTime.now().toUtc();
    final count = await (update(products)
          ..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
        .write(
      ProductsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
    return count > 0;
  }
}