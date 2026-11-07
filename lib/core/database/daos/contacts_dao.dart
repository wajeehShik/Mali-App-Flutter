import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/contacts_table.dart';

part 'contacts_dao.g.dart';

/// وصول مباشر لجدول العملاء والموردين. لا منطق أعمال هنا.
@DriftAccessor(tables: [Contacts])
class ContactsDao extends DatabaseAccessor<AppDatabase>
    with _$ContactsDaoMixin {
  ContactsDao(super.db);

  /// العملاء (customer + both) غير المحذوفين، وتتحدث تلقائيًا.
  Stream<List<ContactRow>> watchCustomers() =>
      _watchKinds([ContactKind.customer, ContactKind.both]);

  /// الموردون (supplier + both) غير المحذوفين، وتتحدث تلقائيًا.
  Stream<List<ContactRow>> watchSuppliers() =>
      _watchKinds([ContactKind.supplier, ContactKind.both]);

  Stream<List<ContactRow>> _watchKinds(List<ContactKind> kinds) {
    final names = kinds.map((k) => k.name).toList();
    final query = select(contacts)
      ..where((c) => c.deletedAt.isNull() & c.kind.isIn(names))
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.watch();
  }

  /// كل جهات الاتصال غير المحذوفة.
  Future<List<ContactRow>> getAll() {
    final query = select(contacts)
      ..where((c) => c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.get();
  }

  /// بحث بالاسم أو الهاتف (غير المحذوفين).
  Future<List<ContactRow>> search(String text) {
    final pattern = '%${text.trim()}%';
    final query = select(contacts)
      ..where((c) =>
          c.deletedAt.isNull() &
          (c.name.like(pattern) | c.phone.like(pattern)))
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.get();
  }

  Future<ContactRow?> getById(String id) {
    final query = select(contacts)
      ..where((c) => c.id.equals(id) & c.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  Future<void> insertContact(ContactsCompanion entry) {
    return into(contacts).insert(entry);
  }

  /// يعدّل الحقول الممرَّرة فقط. يعيد true إن وُجد السجل.
  Future<bool> updateContact(String id, ContactsCompanion changes) async {
    final count = await (update(contacts)
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
    final count = await (update(contacts)
          ..where((c) => c.id.equals(id) & c.deletedAt.isNull()))
        .write(
      ContactsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
    return count > 0;
  }
}