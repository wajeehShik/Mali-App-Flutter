import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories_table.dart';

part 'categories_dao.g.dart';

/// وصول مباشر لجدول التصنيفات. لا منطق أعمال هنا.
@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  /// تصنيفات نوع معيّن (غير المحذوفة) مرتبة بالاسم، وتتحدث تلقائيًا.
  Stream<List<CategoryRow>> watchByKind(CategoryKind kind) {
    final query = select(categories)
      ..where((c) => c.deletedAt.isNull() & c.kind.equalsValue(kind))
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.watch();
  }

  /// كل التصنيفات غير المحذوفة.
  Future<List<CategoryRow>> getAll() {
    final query = select(categories)
      ..where((c) => c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.get();
  }

  Future<CategoryRow?> getById(String id) {
    final query = select(categories)
      ..where((c) => c.id.equals(id) & c.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  Future<void> insertCategory(CategoriesCompanion entry) {
    return into(categories).insert(entry);
  }

  /// يعدّل الحقول الممرَّرة فقط. يعيد true إن وُجد السجل.
  Future<bool> updateCategory(String id, CategoriesCompanion changes) async {
    final count = await (update(categories)
          ..where((c) => c.id.equals(id) & c.deletedAt.isNull()))
        .write(
      changes.copyWith(
        updatedAt: Value(DateTime.now().toUtc()),
        syncStatus: const Value('pending'),
      ),
    );
    return count > 0;
  }

  /// حذف ناعم: يبقى السجل في القاعدة ويختفي من القراءات.
  Future<bool> softDelete(String id) async {
    final now = DateTime.now().toUtc();
    final count = await (update(categories)
          ..where((c) => c.id.equals(id) & c.deletedAt.isNull()))
        .write(
      CategoriesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
    return count > 0;
  }
}