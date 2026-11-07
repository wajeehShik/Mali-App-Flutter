import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/accounts_table.dart';

part 'accounts_dao.g.dart';

/// وصول مباشر لجدول الحسابات. لا منطق أعمال هنا.
@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

  /// الحسابات الفعّالة (غير محذوفة وغير مؤرشفة) مرتبة بالاسم، وتتحدث تلقائيًا.
  Stream<List<AccountRow>> watchActive() {
    final query = select(accounts)
      ..where((a) => a.deletedAt.isNull() & a.isArchived.equals(false))
      ..orderBy([(a) => OrderingTerm.asc(a.name)]);
    return query.watch();
  }

  /// كل الحسابات غير المحذوفة (بما فيها المؤرشفة).
  Future<List<AccountRow>> getAll() {
    final query = select(accounts)
      ..where((a) => a.deletedAt.isNull())
      ..orderBy([(a) => OrderingTerm.asc(a.name)]);
    return query.get();
  }

  Future<AccountRow?> getById(String id) {
    final query = select(accounts)
      ..where((a) => a.id.equals(id) & a.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  Future<void> insertAccount(AccountsCompanion entry) {
    return into(accounts).insert(entry);
  }

  /// يعدّل الحقول الممرَّرة فقط. يعيد true إن وُجد السجل.
  Future<bool> updateAccount(String id, AccountsCompanion changes) async {
    final count = await (update(accounts)
          ..where((a) => a.id.equals(id) & a.deletedAt.isNull()))
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
    final count = await (update(accounts)
          ..where((a) => a.id.equals(id) & a.deletedAt.isNull()))
        .write(
      AccountsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
    return count > 0;
  }
}