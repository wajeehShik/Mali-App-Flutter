import '../../../core/database/app_database.dart';
import '../../../core/database/tables/transactions_table.dart'
    as db_transactions;
import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../domain/transaction_entry.dart';
import '../domain/transaction_repository.dart';

/// تنفيذ قراءة سجل المعاملات من Drift. لا يكتب أو يغير أي بيانات.
class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<TransactionEntry>> watchTransactions({
    DateTime? from,
    DateTime? to,
    FinancialTransactionType? type,
    String? accountId,
  }) {
    final start = from ?? DateTime.utc(1900);
    final end = to ?? DateTime.utc(9999, 12, 31, 23, 59, 59);

    return _db.transactionsDao.watchByDateRange(start, end).asyncMap(
      (rows) async {
        final filtered = rows.where(
          (row) => _matches(
            row,
            type: type,
            accountId: accountId,
          ),
        );

        return Future.wait(filtered.map(_fromRow));
      },
    );
  }

  @override
  Future<Result<List<TransactionEntry>>> getTransactions({
    DateTime? from,
    DateTime? to,
    FinancialTransactionType? type,
    String? accountId,
  }) {
    return guardAsync(() async {
      final rows = await _db.transactionsDao.getAll();

      final filtered = rows.where((row) {
        if (from != null && row.date.isBefore(from)) return false;
        if (to != null && !row.date.isBefore(to)) return false;

        return _matches(row, type: type, accountId: accountId);
      });

      return Future.wait(filtered.map(_fromRow));
    });
  }

  @override
  Future<Result<List<TransactionEntry>>> search(
    String query, {
    FinancialTransactionType? type,
  }) {
    return guardAsync(() async {
      final term = query.trim().toLowerCase();
      final rows = await _db.transactionsDao.getAll();

      final filtered = rows.where((row) {
        if (type != null && _mapType(row.type) != type) return false;
        if (term.isEmpty) return true;

        return row.id.toLowerCase().contains(term) ||
            (row.note?.toLowerCase().contains(term) ?? false);
      });

      return Future.wait(filtered.map(_fromRow));
    });
  }

  @override
  Future<Result<TransactionEntry?>> getById(String id) {
    return guardAsync(() async {
      final row = await _db.transactionsDao.getById(id);
      if (row == null) return null;

      return _fromRow(row);
    });
  }

  bool _matches(
    TransactionRow row, {
    FinancialTransactionType? type,
    String? accountId,
  }) {
    if (type != null && _mapType(row.type) != type) return false;

    // في التحويل، يُطابق البحث الحساب المصدر أو الحساب الوجهة.
    if (accountId != null &&
        row.accountId != accountId &&
        row.toAccountId != accountId) {
      return false;
    }

    return true;
  }

  FinancialTransactionType _mapType(
    db_transactions.TransactionType type,
  ) {
    return switch (type) {
      db_transactions.TransactionType.income =>
        FinancialTransactionType.income,
      db_transactions.TransactionType.expense =>
        FinancialTransactionType.expense,
      db_transactions.TransactionType.sale =>
        FinancialTransactionType.sale,
      db_transactions.TransactionType.purchase =>
        FinancialTransactionType.purchase,
      db_transactions.TransactionType.transfer =>
        FinancialTransactionType.transfer,
      db_transactions.TransactionType.debtIn =>
        FinancialTransactionType.debtIn,
      db_transactions.TransactionType.debtOut =>
        FinancialTransactionType.debtOut,
    };
  }

  Future<TransactionEntry> _fromRow(TransactionRow row) async {
    final type = _mapType(row.type);

    final itemRows =
        type == FinancialTransactionType.sale ||
                type == FinancialTransactionType.purchase
            ? await _db.transactionsDao.getItems(row.id)
            : const <TransactionItemRow>[];

    return TransactionEntry(
      id: row.id,
      type: type,
      date: row.date,
      accountId: row.accountId,
      toAccountId: row.toAccountId,
      contactId: row.contactId,
      categoryId: row.categoryId,
      total: Money(row.total),
      paidAmount: Money(row.paidAmount),
      note: row.note,
      items: itemRows
          .map(
            (item) => TransactionEntryItem(
              productId: item.productId,
              quantityMilli: item.quantity,
              unitPrice: Money(item.unitPrice),
              unitCost: Money(item.unitCost),
            ),
          )
          .toList(growable: false),
    );
  }
}
