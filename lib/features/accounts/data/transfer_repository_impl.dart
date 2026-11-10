import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/outbox_table.dart';
import '../../../core/database/tables/transactions_table.dart'
    as db_transactions;
import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../domain/account_transfer.dart';
import '../domain/transfer_repository.dart';
import '../domain/transfer_validator.dart';

/// تنفيذ التحويلات عبر قاعدة Drift المحلية.
///
/// يحفظ سجل التحويل وعنصر outbox المرتبط به داخل معاملة واحدة.
class TransferRepositoryImpl implements TransferRepository {
  TransferRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<Result<void>> createTransfer(AccountTransfer transfer) {
    final validationFailure = TransferValidator.validate(transfer);
    if (validationFailure != null) {
      return Future.value(Err<void>(validationFailure));
    }

    return guardAsync(() async {
      await _db.transaction(() async {
        final fromAccount = await _getUsableAccount(transfer.fromAccountId);
        final toAccount = await _getUsableAccount(transfer.toAccountId);

        if (fromAccount.currency != toAccount.currency) {
          throw const FailureException(
            ConflictFailure('لا يمكن التحويل بين حسابين بعملتين مختلفتين.'),
          );
        }

        final now = DateTime.now().toUtc();

        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: Value(transfer.id),
                type: db_transactions.TransactionType.transfer,
                date: transfer.date.toUtc(),
                accountId: transfer.fromAccountId,
                toAccountId: Value(transfer.toAccountId),
                total: transfer.amount.minor,
                paidAmount: transfer.amount.minor,
                note: Value(_cleanNote(transfer.note)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        final row = await _getTransferRow(transfer.id);
        await _enqueue(
          entityId: transfer.id,
          operation: OutboxOperation.create,
          payload: _payloadFor(row),
        );
      });
    });
  }

  @override
  Future<Result<AccountTransfer?>> getTransferById(String id) {
    return guardAsync(() async {
      final row = await _getTransferRowOrNull(id);
      if (row == null || row.deletedAt != null) {
        return null;
      }

      if (row.type != db_transactions.TransactionType.transfer ||
          row.toAccountId == null) {
        throw const FailureException(
          ConflictFailure('العملية الموجودة ليست تحويلًا صالحًا.'),
        );
      }

      return AccountTransfer(
        id: row.id,
        fromAccountId: row.accountId,
        toAccountId: row.toAccountId!,
        amount: Money(row.total),
  date: row.date,
        note: row.note,
      );
    });
  }

  @override
  Future<Result<void>> softDeleteTransfer(String id) {
    return guardAsync(() async {
      await _db.transaction(() async {
        final row = await _getTransferRowOrNull(id);

        if (row == null || row.deletedAt != null) {
          throw const FailureException(
            NotFoundFailure('التحويل غير موجود.'),
          );
        }

        if (row.type != db_transactions.TransactionType.transfer ||
            row.toAccountId == null) {
          throw const FailureException(
            ConflictFailure('العملية المطلوبة ليست تحويلًا صالحًا.'),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.transactions)
              ..where(
                (transaction) =>
                    transaction.id.equals(id) &
                    transaction.deletedAt.isNull(),
              ))
            .write(
          TransactionsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final deletedRow = await _getTransferRow(id);
        await _enqueue(
          entityId: id,
          operation: OutboxOperation.delete,
          payload: _payloadFor(deletedRow),
        );
      });
    });
  }

  Future<AccountRow> _getUsableAccount(String id) async {
    final account = await _db.accountsDao.getById(id);

    if (account == null) {
      throw const FailureException(
        NotFoundFailure('أحد الحسابين غير موجود.'),
      );
    }

    if (account.isArchived) {
      throw const FailureException(
        ConflictFailure('لا يمكن إجراء تحويل من حساب مؤرشف أو إليه.'),
      );
    }

    return account;
  }

  Future<TransactionRow> _getTransferRow(String id) async {
    final row = await _getTransferRowOrNull(id);

    if (row == null) {
      throw const FailureException(NotFoundFailure('التحويل غير موجود.'));
    }

    return row;
  }

  Future<TransactionRow?> _getTransferRowOrNull(String id) {
    final query = _db.select(_db.transactions)
      ..where((transaction) => transaction.id.equals(id));

    return query.getSingleOrNull();
  }

  Future<void> _enqueue({
    required String entityId,
    required OutboxOperation operation,
    required String payload,
  }) async {
    await _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            entity: 'transactions',
            entityId: entityId,
            operation: operation,
            payload: payload,
          ),
        );
  }

  String _payloadFor(TransactionRow row) {
    return jsonEncode({
      'id': row.id,
      'type': row.type.name,
      'date': row.date.toUtc().toIso8601String(),
      'account_id': row.accountId,
      'to_account_id': row.toAccountId,
      'total': row.total,
      'paid_amount': row.paidAmount,
      'note': row.note,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
      'sync_status': row.syncStatus,
      'remote_id': row.remoteId,
    });
  }

  String? _cleanNote(String? note) {
    final clean = note?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
