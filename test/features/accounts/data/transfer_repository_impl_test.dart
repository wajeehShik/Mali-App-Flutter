import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/outbox_table.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/accounts/data/transfer_repository_impl.dart';
import 'package:mali/features/accounts/domain/account_transfer.dart';

import '../../../core/database/database_test_helper.dart';

void main() {
  late AppDatabase db;
  late TransferRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = TransferRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<(String, String)> createAccounts() async {
    final sourceId = await addAccount(
      db,
      name: 'المصدر',
      opening: 10000,
    );
    final targetId = await addAccount(
      db,
      name: 'الوجهة',
      opening: 2000,
    );
    return (sourceId, targetId);
  }

  AccountTransfer makeTransfer({
    String id = 'transfer-1',
    String fromAccountId = 'acc-المصدر',
    String toAccountId = 'acc-الوجهة',
    Money amount = const Money(3000),
    String? note,
  }) {
    return AccountTransfer(
      id: id,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
      date: DateTime.utc(2026, 11, 9, 12),
      note: note,
    );
  }

  group('createTransfer', () {
    test('ينشئ التحويل ويسجل outbox داخل المعاملة', () async {
      final (sourceId, targetId) = await createAccounts();

      final result = await repository.createTransfer(
        makeTransfer(
          fromAccountId: sourceId,
          toAccountId: targetId,
          note: 'تحويل تجريبي',
        ),
      );

      expect(result.isOk, isTrue);

      final row = await db.transactionsDao.getById('transfer-1');
      expect(row, isNotNull);
      expect(row!.type.name, 'transfer');
      expect(row.accountId, sourceId);
      expect(row.toAccountId, targetId);
      expect(row.total, 3000);
      expect(row.paidAmount, 3000);
      expect(row.note, 'تحويل تجريبي');

      final outbox = await db.outboxDao.getPending();
      expect(outbox, hasLength(1));
      expect(outbox.single.entity, 'transactions');
      expect(outbox.single.entityId, 'transfer-1');
      expect(outbox.single.operation, OutboxOperation.create);

      final payload = jsonDecode(outbox.single.payload) as Map<String, dynamic>;
      expect(payload['type'], 'transfer');
      expect(payload['account_id'], sourceId);
      expect(payload['to_account_id'], targetId);
      expect(payload['total'], 3000);
      expect(payload['paid_amount'], 3000);
    });

    test('يرفض التحويل إلى الحساب نفسه دون كتابة بيانات', () async {
      final sourceId = await addAccount(db, name: 'وحيد');

      final result = await repository.createTransfer(
        makeTransfer(
          fromAccountId: sourceId,
          toAccountId: sourceId,
        ),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(await db.transactionsDao.getById('transfer-1'), isNull);
      expect(await db.outboxDao.getPending(), isEmpty);
    });

    test('يرفض مبلغًا صفريًا دون كتابة بيانات', () async {
      final (sourceId, targetId) = await createAccounts();

      final result = await repository.createTransfer(
        makeTransfer(
          fromAccountId: sourceId,
          toAccountId: targetId,
          amount: Money.zero,
        ),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(await db.transactionsDao.getById('transfer-1'), isNull);
      expect(await db.outboxDao.getPending(), isEmpty);
    });

    test('يرفض حسابًا غير موجود', () async {
      final targetId = await addAccount(db, name: 'الوجهة');

      final result = await repository.createTransfer(
        makeTransfer(
          fromAccountId: 'missing-account',
          toAccountId: targetId,
        ),
      );

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(await db.transactionsDao.getById('transfer-1'), isNull);
      expect(await db.outboxDao.getPending(), isEmpty);
    });

    test('يرفض التحويل من حساب مؤرشف', () async {
      final sourceId = await addAccount(db, name: 'المصدر');
      final targetId = await addAccount(db, name: 'الوجهة');

      await db.accountsDao.updateAccount(
        sourceId,
        const AccountsCompanion(isArchived: Value(true)),
      );

      final result = await repository.createTransfer(
        makeTransfer(
          fromAccountId: sourceId,
          toAccountId: targetId,
        ),
      );

      expect(result.failureOrNull, isA<ConflictFailure>());
      expect(await db.transactionsDao.getById('transfer-1'), isNull);
      expect(await db.outboxDao.getPending(), isEmpty);
    });

    test('يفشل إنشاء التحويل إذا تعذّر إدخال outbox ويتراجع عن العملية',
        () async {
      final (sourceId, targetId) = await createAccounts();

      await db.customStatement('''
        CREATE TRIGGER reject_outbox_insert
        BEFORE INSERT ON outbox
        BEGIN
          SELECT RAISE(ABORT, 'outbox unavailable');
        END
      ''');

      final result = await repository.createTransfer(
        makeTransfer(
          fromAccountId: sourceId,
          toAccountId: targetId,
        ),
      );

      expect(result.isErr, isTrue);
      expect(await db.transactionsDao.getById('transfer-1'), isNull);
      expect(await db.outboxDao.getPending(), isEmpty);
    });
  });

  group('getTransferById', () {
    test('يرجع تفاصيل التحويل الموجود', () async {
      final (sourceId, targetId) = await createAccounts();
      final transfer = makeTransfer(
        fromAccountId: sourceId,
        toAccountId: targetId,
        note: 'ملاحظة',
      );

      await repository.createTransfer(transfer);

      final result = await repository.getTransferById('transfer-1');
final actual = result.valueOrNull;

expect(actual, isNotNull);
expect(actual!.id, transfer.id);
expect(actual.fromAccountId, transfer.fromAccountId);
expect(actual.toAccountId, transfer.toAccountId);
expect(actual.amount, transfer.amount);
expect(actual.note, transfer.note);
expect(actual.date.toUtc(), transfer.date.toUtc());

    });

    test('يرجع null إذا لم يوجد التحويل', () async {
      final result = await repository.getTransferById('missing');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNull);
    });
  });

  group('softDeleteTransfer', () {
    test('يحذف التحويل حذفًا ناعمًا ويسجل outbox', () async {
      final (sourceId, targetId) = await createAccounts();

      await repository.createTransfer(
        makeTransfer(
          fromAccountId: sourceId,
          toAccountId: targetId,
        ),
      );

      final result = await repository.softDeleteTransfer('transfer-1');

      expect(result.isOk, isTrue);
      expect(await db.transactionsDao.getById('transfer-1'), isNull);

      final rows = await (db.select(db.transactions)
            ..where((transaction) => transaction.id.equals('transfer-1')))
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.deletedAt, isNotNull);

      final outbox = await db.outboxDao.getPending();
      expect(outbox, hasLength(2));
      expect(outbox.last.operation, OutboxOperation.delete);
    });

    test('يرجع NotFound عند حذف تحويل غير موجود', () async {
      final result = await repository.softDeleteTransfer('missing');

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(await db.outboxDao.getPending(), isEmpty);
    });
  });
}
