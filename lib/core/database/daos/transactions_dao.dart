import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/transaction_items_table.dart';
import '../tables/transactions_table.dart';

part 'transactions_dao.g.dart';

/// وصول مباشر لجدولي العمليات وبنودها. لا منطق أعمال (أرصدة/ديون) هنا.
@DriftAccessor(tables: [Transactions, TransactionItems])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  /// العمليات ضمن مدى تاريخ [from, to) غير المحذوفة، الأحدث أولًا، وتتحدث تلقائيًا.
  Stream<List<TransactionRow>> watchByDateRange(DateTime from, DateTime to) {
    final query = select(transactions)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.date.isBiggerOrEqualValue(from) &
          t.date.isSmallerThanValue(to))
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    return query.watch();
  }

  /// كل العمليات غير المحذوفة (تُستخدم في الحسابات والتصدير).
  Future<List<TransactionRow>> getAll() {
    final query = select(transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.get();
  }

  Future<TransactionRow?> getById(String id) {
    final query = select(transactions)
      ..where((t) => t.id.equals(id) & t.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  /// بنود عملية (غير المحذوفة).
  Future<List<TransactionItemRow>> getItems(String transactionId) {
    final query = select(transactionItems)
      ..where((i) =>
          i.transactionId.equals(transactionId) & i.deletedAt.isNull())
      ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]);
    return query.get();
  }

  /// يحفظ العملية وبنودها في معاملة واحدة: إما تنجح كلها أو تفشل كلها.
  Future<void> insertWithItems(
    TransactionsCompanion entry,
    List<TransactionItemsCompanion> items,
  ) {
    return transaction(() async {
      await into(transactions).insert(entry);
      for (final item in items) {
        await into(transactionItems).insert(item);
      }
    });
  }

  /// يعدّل العملية ويستبدل بنودها في معاملة واحدة.
  /// [items] هي القائمة الجديدة الكاملة (البنود القديمة تُحذف حذفًا ناعمًا).
  /// يعيد false إن لم توجد العملية.
  Future<bool> updateWithItems(
    String id,
    TransactionsCompanion changes,
    List<TransactionItemsCompanion> items,
  ) {
    return transaction(() async {
      final now = DateTime.now().toUtc();

      final count = await (update(transactions)
            ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
          .write(
        changes.copyWith(
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
      if (count == 0) {
        return false;
      }

      await (update(transactionItems)
            ..where((i) => i.transactionId.equals(id) & i.deletedAt.isNull()))
          .write(
        TransactionItemsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );

      for (final item in items) {
        await into(transactionItems).insert(item);
      }
      return true;
    });
  }

  /// حذف ناعم للعملية وبنودها معًا. يعيد true إن وُجدت العملية.
  Future<bool> softDelete(String id) {
    return transaction(() async {
      final now = DateTime.now().toUtc();

      final count = await (update(transactions)
            ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
          .write(
        TransactionsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
      if (count == 0) {
        return false;
      }

      await (update(transactionItems)
            ..where((i) => i.transactionId.equals(id) & i.deletedAt.isNull()))
          .write(
        TransactionItemsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
      return true;
    });
  }
}