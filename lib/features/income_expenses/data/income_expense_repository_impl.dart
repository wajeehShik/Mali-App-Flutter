import 'dart:convert';

import 'package:drift/drift.dart';
import '../../../core/utils/money.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/outbox_table.dart';
import '../../../core/database/tables/transactions_table.dart'
    as db_transactions;
import '../../../core/errors/failure.dart';
import '../domain/income_expense.dart';
import '../domain/income_expense_repository.dart';

/// تنفيذ مستودع الإيرادات والمصروفات محليًا عبر Drift.
/// حفظ الحركة وسجل outbox يتمان داخل المعاملة نفسها.
class IncomeExpenseRepositoryImpl implements IncomeExpenseRepository {
  IncomeExpenseRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<IncomeExpense>> watchByType(
    IncomeExpenseType type, {
    DateTime? from,
    DateTime? to,
    String? categoryId,
  }) {
    final start = from ?? DateTime.utc(1900);
    final end = to ?? DateTime.utc(9999, 12, 31, 23, 59, 59);

    return _db.transactionsDao.watchByDateRange(start, end).map((rows) {
      return rows
          .where((row) =>
              row.type.name == type.name &&
              (categoryId == null || row.categoryId == categoryId))
          .map(_fromRow)
          .toList(growable: false);
    });
  }

  @override
  Future<Result<List<IncomeExpense>>> getAll() {
    return guardAsync(() async {
      final rows = await _db.transactionsDao.getAll();
      return rows
          .where(_isIncomeExpense)
          .map(_fromRow)
          .toList(growable: false);
    });
  }

  @override
  Future<Result<List<IncomeExpense>>> search(String query) {
    return guardAsync(() async {
      final term = query.trim().toLowerCase();
      final rows = await _db.transactionsDao.getAll();

      return rows.where(_isIncomeExpense).where((row) {
        if (term.isEmpty) return true;

        return row.id.toLowerCase().contains(term) ||
            (row.note?.toLowerCase().contains(term) ?? false);
      }).map(_fromRow).toList(growable: false);
    });
  }

  @override
  Future<Result<IncomeExpense?>> getById(String id) {
    return guardAsync(() async {
      final row = await _db.transactionsDao.getById(id);
      if (row == null || !_isIncomeExpense(row)) return null;
      return _fromRow(row);
    });
  }

  @override
  Future<Result<void>> create(IncomeExpense entry) {
    final failure = _validate(entry);
    if (failure != null) return Future.value(Err<void>(failure));

    return guardAsync(() async {
      await _db.transaction(() async {
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: Value(entry.id),
                type: db_transactions.TransactionType.values
                    .byName(entry.type.name),
                date: entry.date.toUtc(),
                accountId: entry.accountId,
                categoryId: Value(_cleanOptional(entry.categoryId)),
                total: entry.amount.minor,
                paidAmount: entry.amount.minor,
                note: Value(_cleanOptional(entry.note)),
              ),
            );

        final row = await _readRow(entry.id);
        await _enqueue(
          row: row,
          operation: OutboxOperation.create,
        );
      });
    });
  }

  @override
  Future<Result<void>> update(IncomeExpense entry) {
    final failure = _validate(entry);
    if (failure != null) return Future.value(Err<void>(failure));

    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(entry.id);
        if (existing == null || !_isIncomeExpense(existing)) {
          throw const FailureException(
            NotFoundFailure('الإيراد أو المصروف غير موجود.'),
          );
        }

        final now = DateTime.now().toUtc();

        await (_db.update(_db.transactions)
              ..where((row) => row.id.equals(entry.id)))
            .write(
          TransactionsCompanion(
            type: Value(
              db_transactions.TransactionType.values.byName(entry.type.name),
            ),
            date: Value(entry.date.toUtc()),
            accountId: Value(entry.accountId),
            categoryId: Value(_cleanOptional(entry.categoryId)),
            total: Value(entry.amount.minor),
            paidAmount: Value(entry.amount.minor),
            note: Value(_cleanOptional(entry.note)),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final row = await _readRow(entry.id);
        await _enqueue(row: row, operation: OutboxOperation.update);
      });
    });
  }

  @override
  Future<Result<void>> softDelete(String id) {
    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(id);

        if (existing == null || !_isIncomeExpense(existing)) {
          throw const FailureException(
            NotFoundFailure('الإيراد أو المصروف غير موجود.'),
          );
        }

        final now = DateTime.now().toUtc();

        await (_db.update(_db.transactions)
              ..where((row) => row.id.equals(id)))
            .write(
          TransactionsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final row = await _readRow(id);
        await _enqueue(row: row, operation: OutboxOperation.delete);
      });
    });
  }

  bool _isIncomeExpense(TransactionRow row) =>
      row.type == db_transactions.TransactionType.income ||
      row.type == db_transactions.TransactionType.expense;

  IncomeExpense _fromRow(TransactionRow row) {
    return IncomeExpense(
      id: row.id,
      type: IncomeExpenseType.values.byName(row.type.name),
      date: row.date,
      accountId: row.accountId,
      amount: Money(row.total),
      categoryId: row.categoryId,
      note: row.note,
    );
  }

  Failure? _validate(IncomeExpense entry) {
    final errors = <String, String>{};

    if (entry.id.trim().isEmpty) {
      errors['id'] = 'معرّف الحركة مطلوب.';
    }
    if (entry.accountId.trim().isEmpty) {
      errors['accountId'] = 'الحساب مطلوب.';
    }
    if (entry.amount.minor <= 0) {
      errors['amount'] = 'المبلغ يجب أن يكون أكبر من صفر.';
    }
    if ((entry.note?.trim().length ?? 0) > 500) {
      errors['note'] = 'الملاحظة طويلة جدًا.';
    }

    if (errors.isEmpty) return null;
    return ValidationFailure(
      'تحقق من بيانات الإيراد أو المصروف.',
      fieldErrors: errors,
    );
  }

  String? _cleanOptional(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  Future<TransactionRow> _readRow(String id) async {
    final query = _db.select(_db.transactions)
      ..where((row) => row.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) {
      throw const FailureException(
        NotFoundFailure('الإيراد أو المصروف غير موجود.'),
      );
    }
    return row;
  }

  Future<TransactionRow?> _readActiveRowOrNull(String id) {
    final query = _db.select(_db.transactions)
      ..where((row) => row.id.equals(id) & row.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  Future<void> _enqueue({
    required TransactionRow row,
    required OutboxOperation operation,
  }) async {
    final payload = jsonEncode({
      'id': row.id,
      'type': row.type.name,
      'date': row.date.toUtc().toIso8601String(),
      'account_id': row.accountId,
      'to_account_id': row.toAccountId,
      'contact_id': row.contactId,
      'category_id': row.categoryId,
      'total': row.total,
      'paid_amount': row.paidAmount,
      'note': row.note,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
      'sync_status': row.syncStatus,
      'remote_id': row.remoteId,
    });

    await _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            entity: 'transactions',
            entityId: row.id,
            operation: operation,
            payload: payload,
          ),
        );
  }
}
