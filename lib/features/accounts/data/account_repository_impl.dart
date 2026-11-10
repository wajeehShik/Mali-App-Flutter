import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/accounts_table.dart' as db_accounts;
import '../../../core/database/tables/outbox_table.dart';
import '../../../core/database/tables/transactions_table.dart'
    as db_transactions;
import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../domain/account.dart';
import '../domain/account_balance.dart';
import '../domain/account_repository.dart';

/// تنفيذ مستودع الحسابات على Drift.
///
/// كل تغيير محلي للحساب وعنصر outbox المقابل يُحفظان في معاملة واحدة.
class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Account>> watchActive() {
    return _db.accountsDao.watchActive().map(
          (rows) => rows.map(_fromRow).toList(growable: false),
        );
  }

  @override
  Future<Result<List<Account>>> getAll() {
    return guardAsync(() async {
      final rows = await _db.accountsDao.getAll();
      return rows.map(_fromRow).toList(growable: false);
    });
  }

  @override
  Future<Result<Account?>> getById(String id) {
    return guardAsync(() async {
      final row = await _db.accountsDao.getById(id);
      return row == null ? null : _fromRow(row);
    });
  }

  @override
  Future<Result<void>> create(Account account) {
    final validationFailure = _validate(account);
    if (validationFailure != null) {
      return Future.value(Err<void>(validationFailure));
    }

    return guardAsync(() async {
  await _db.transaction(() async {
  await _db.into(_db.accounts).insert(
        AccountsCompanion.insert(
          id: Value(account.id),
          name: account.name.trim(),
          type: db_accounts.AccountType.values.byName(account.type.name),
          openingBalance: Value(account.openingBalance.minor),
          currency: Value(account.currency),
          isArchived: Value(account.isArchived),
        ),
      );

  final row = await _readActiveRow(account.id);
  await _enqueue(
    entityId: account.id,
    operation: OutboxOperation.create,
    row: row,
  );
});
    });
  }

  @override
  Future<Result<void>> update(Account account) {
    final validationFailure = _validate(account);
    if (validationFailure != null) {
      return Future.value(Err<void>(validationFailure));
    }

    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(account.id);
        if (existing == null) {
          throw const FailureException(NotFoundFailure('الحساب غير موجود.'));
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.accounts)
              ..where((table) => table.id.equals(account.id)))
            .write(
          AccountsCompanion(
            name: Value(account.name.trim()),
            type: Value(
              db_accounts.AccountType.values.byName(account.type.name),
            ),
            openingBalance: Value(account.openingBalance.minor),
            currency: Value(account.currency),
            isArchived: Value(account.isArchived),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final updated = await _readActiveRow(account.id);
        await _enqueue(
          entityId: account.id,
          operation: OutboxOperation.update,
          row: updated,
        );
      });
    });
  }

  @override
  Future<Result<void>> archive(String id) {
    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(id);
        if (existing == null) {
          throw const FailureException(NotFoundFailure('الحساب غير موجود.'));
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.accounts)..where((table) => table.id.equals(id)))
            .write(
          AccountsCompanion(
            isArchived: const Value(true),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final archived = await _readActiveRow(id);
        await _enqueue(
          entityId: id,
          operation: OutboxOperation.update,
          row: archived,
        );
      });
    });
  }

  @override
  Future<Result<void>> softDelete(String id) {
    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(id);
        if (existing == null) {
          throw const FailureException(NotFoundFailure('الحساب غير موجود.'));
        }

        final linkedTransactions = await (_db.select(_db.transactions)
              ..where(
                (table) =>
                    table.deletedAt.isNull() &
                    (table.accountId.equals(id) | table.toAccountId.equals(id)),
              ))
            .get();
        if (linkedTransactions.isNotEmpty) {
          throw const FailureException(
            ConflictFailure(
              'لا يمكن حذف حساب مرتبط بعمليات. أرشفه بدلًا من ذلك.',
            ),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.accounts)..where((table) => table.id.equals(id)))
            .write(
          AccountsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final deleted = await _readRowIncludingDeleted(id);
        await _enqueue(
          entityId: id,
          operation: OutboxOperation.delete,
          row: deleted,
        );
      });
    });
  }

  @override
  Future<Result<Money>> getBalance(String id) {
    return guardAsync(() async {
      final account = await _db.accountsDao.getById(id);
      if (account == null) {
        throw const FailureException(NotFoundFailure('الحساب غير موجود.'));
      }

      final rows = await _db.transactionsDao.getAll();
      final movements = rows.map((row) {
        final type = switch (row.type) {
          db_transactions.TransactionType.income =>
            AccountMovementType.income,
          db_transactions.TransactionType.expense =>
            AccountMovementType.expense,
          db_transactions.TransactionType.sale => AccountMovementType.sale,
          db_transactions.TransactionType.purchase =>
            AccountMovementType.purchase,
          db_transactions.TransactionType.transfer =>
            AccountMovementType.transfer,
          db_transactions.TransactionType.debtIn =>
            AccountMovementType.debtIn,
          db_transactions.TransactionType.debtOut =>
            AccountMovementType.debtOut,
        };

        return AccountMovement(
          type: type,
          amount: Money(row.paidAmount),
          accountId: row.accountId,
          toAccountId: row.toAccountId,
        );
      });

      return calculateAccountBalance(
        account: _fromRow(account),
        movements: movements,
      );
    });
  }

  Failure? _validate(Account account) {
    final name = account.name.trim();
    if (name.isEmpty) {
      return const ValidationFailure(
        'تحقق من البيانات المدخلة.',
        fieldErrors: {'name': 'اسم الحساب مطلوب.'},
      );
    }
    if (name.length > 100) {
      return const ValidationFailure(
        'تحقق من البيانات المدخلة.',
        fieldErrors: {'name': 'اسم الحساب طويل جدًا.'},
      );
    }
    if (account.id.trim().isEmpty) {
      return const ValidationFailure(
        'تحقق من البيانات المدخلة.',
        fieldErrors: {'id': 'معرّف الحساب مطلوب.'},
      );
    }
    if (account.currency.trim().isEmpty) {
      return const ValidationFailure(
        'تحقق من البيانات المدخلة.',
        fieldErrors: {'currency': 'رمز العملة مطلوب.'},
      );
    }
    return null;
  }

  Account _fromRow(AccountRow row) {
    return Account(
      id: row.id,
      name: row.name,
      type: AccountType.values.byName(row.type.name),
      openingBalance: Money(row.openingBalance),
      currency: row.currency,
      isArchived: row.isArchived,
    );
  }

  Future<AccountRow> _readActiveRow(String id) async {
    final row = await _readActiveRowOrNull(id);
    if (row == null) {
      throw const FailureException(NotFoundFailure('الحساب غير موجود.'));
    }
    return row;
  }

  Future<AccountRow?> _readActiveRowOrNull(String id) {
    final query = _db.select(_db.accounts)
      ..where((table) => table.id.equals(id) & table.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  Future<AccountRow> _readRowIncludingDeleted(String id) async {
    final query = _db.select(_db.accounts)
      ..where((table) => table.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) {
      throw const FailureException(NotFoundFailure('الحساب غير موجود.'));
    }
    return row;
  }

  Future<void> _enqueue({
    required String entityId,
    required OutboxOperation operation,
    required AccountRow row,
  }) async {
    final payload = jsonEncode({
      'id': row.id,
      'name': row.name,
      'type': row.type.name,
      'opening_balance': row.openingBalance,
      'currency': row.currency,
      'is_archived': row.isArchived,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
      'sync_status': row.syncStatus,
      'remote_id': row.remoteId,
    });

    await _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            entity: 'accounts',
            entityId: entityId,
            operation: operation,
            payload: payload,
          ),
        );
  }
}
  