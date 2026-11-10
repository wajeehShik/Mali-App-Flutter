import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/outbox_table.dart';
import '../../../core/database/tables/transactions_table.dart'
    as db_transactions;
import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../domain/debt_balance.dart';
import '../domain/debt_payment.dart';
import '../domain/debt_repository.dart';

/// يحسب أرصدة الديون من سجل العمليات، ويسجل التسديدات كعمليات مستقلة.
class DebtRepositoryImpl implements DebtRepository {
  DebtRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<DebtBalance>> watchBalances() {
    return _db.transactionsDao
        .watchByDateRange(
          DateTime.utc(1900),
          DateTime.utc(9999, 12, 31, 23, 59, 59),
        )
        .map(_calculateFromRows);
  }

  @override
  Future<Result<List<DebtBalance>>> getBalances() {
    return guardAsync(() async {
      final rows = await _db.transactionsDao.getAll();
      return _calculateFromRows(rows);
    });
  }

  @override
  Future<Result<DebtBalance?>> getBalance(
    String contactId,
    DebtDirection direction,
  ) {
    return guardAsync(() async {
      final rows = await _db.transactionsDao.getAll();
      final balances = _calculateFromRows(rows);

      for (final balance in balances) {
        if (balance.contactId == contactId &&
            balance.direction == direction) {
          return balance;
        }
      }

      return null;
    });
  }

  @override
  Future<Result<void>> recordPayment(DebtPayment payment) {
    final validationFailure = _validate(payment);
    if (validationFailure != null) {
      return Future.value(Err<void>(validationFailure));
    }

    return guardAsync(() async {
      await _db.transaction(() async {
        final contact = await _readActiveContact(payment.contactId);
        _validateContactDirection(contact, payment.direction);

        final transactionRows = await _db.transactionsDao.getAll();
        final currentBalance = _calculateFromRows(transactionRows)
            .where(
              (balance) =>
                  balance.contactId == payment.contactId &&
                  balance.direction == payment.direction,
            )
            .firstOrNull;

        if (currentBalance == null || currentBalance.amount.minor <= 0) {
          throw const FailureException(
            ConflictFailure('لا يوجد رصيد دين مستحق لهذه الجهة.'),
          );
        }

        if (payment.amount.minor > currentBalance.amount.minor) {
          throw const FailureException(
            ConflictFailure('مبلغ السداد أكبر من الدين المستحق.'),
          );
        }

        final dbType = payment.direction == DebtDirection.receivable
            ? db_transactions.TransactionType.debtIn
            : db_transactions.TransactionType.debtOut;

        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: Value(payment.id),
                type: dbType,
                date: payment.date.toUtc(),
                accountId: payment.accountId,
                contactId: Value(payment.contactId),
                total: payment.amount.minor,
                paidAmount: payment.amount.minor,
                note: Value(_cleanOptional(payment.note)),
              ),
            );

        final row = await _readTransactionRow(payment.id);
        await _enqueue(row: row);
      });
    });
  }

  List<DebtBalance> _calculateFromRows(List<TransactionRow> rows) {
    final movements = <DebtMovement>[];

    for (final row in rows) {
      final type = switch (row.type) {
        db_transactions.TransactionType.sale => DebtMovementType.sale,
        db_transactions.TransactionType.purchase => DebtMovementType.purchase,
        db_transactions.TransactionType.debtIn => DebtMovementType.debtIn,
        db_transactions.TransactionType.debtOut => DebtMovementType.debtOut,
        _ => null,
      };

      if (type == null) continue;

      movements.add(
        DebtMovement(
          contactId: row.contactId,
          type: type,
          total: Money(row.total),
          paidAmount: Money(row.paidAmount),
        ),
      );
    }

    return DebtCalculator.calculate(movements);
  }

  Failure? _validate(DebtPayment payment) {
    final errors = <String, String>{};

    if (payment.id.trim().isEmpty) {
      errors['id'] = 'معرّف السداد مطلوب.';
    }
    if (payment.accountId.trim().isEmpty) {
      errors['accountId'] = 'حساب السداد مطلوب.';
    }
    if (payment.contactId.trim().isEmpty) {
      errors['contactId'] = 'العميل أو المورد مطلوب.';
    }
    if (payment.amount.minor <= 0) {
      errors['amount'] = 'مبلغ السداد يجب أن يكون أكبر من صفر.';
    }
    if ((payment.note?.trim().length ?? 0) > 500) {
      errors['note'] = 'الملاحظة طويلة جدًا.';
    }

    if (errors.isEmpty) return null;

    return ValidationFailure(
      'تحقق من بيانات السداد.',
      fieldErrors: errors,
    );
  }

  Future<ContactRow> _readActiveContact(String contactId) async {
    final query = _db.select(_db.contacts)
      ..where(
        (contact) =>
            contact.id.equals(contactId) & contact.deletedAt.isNull(),
      );

    final contact = await query.getSingleOrNull();
    if (contact == null) {
      throw const FailureException(
        NotFoundFailure('العميل أو المورد غير موجود.'),
      );
    }

    return contact;
  }

  void _validateContactDirection(
    ContactRow contact,
    DebtDirection direction,
  ) {
    final kind = contact.kind.name;
    final valid = switch (direction) {
      DebtDirection.receivable =>
        kind == 'customer' || kind == 'both',
      DebtDirection.payable =>
        kind == 'supplier' || kind == 'both',
    };

    if (!valid) {
      throw const FailureException(
        ValidationFailure('نوع جهة الاتصال لا يتوافق مع اتجاه الدين.'),
      );
    }
  }

  Future<TransactionRow> _readTransactionRow(String id) async {
    final query = _db.select(_db.transactions)
      ..where((row) => row.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) {
      throw const FailureException(
        NotFoundFailure('عملية السداد غير موجودة.'),
      );
    }

    return row;
  }

  String? _cleanOptional(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  Future<void> _enqueue({required TransactionRow row}) async {
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
            operation: OutboxOperation.create,
            payload: payload,
          ),
        );
  }
}
