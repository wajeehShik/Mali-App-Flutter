import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/outbox_table.dart';
import 'package:mali/core/database/tables/transactions_table.dart'
    as db_transactions;
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/accounts/data/account_repository_impl.dart';
import 'package:mali/features/accounts/domain/account.dart';

import '../../../core/database/database_test_helper.dart';

void main() {
  late AppDatabase db;
  late AccountRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = AccountRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  Account makeAccount({
    String id = 'account-1',
    String name = 'الصندوق',
    AccountType type = AccountType.cash,
    Money openingBalance = Money.zero,
    bool isArchived = false,
  }) {
    return Account(
      id: id,
      name: name,
      type: type,
      openingBalance: openingBalance,
      isArchived: isArchived,
    );
  }

  group('إنشاء الحساب', () {
    test('يحفظ الحساب وسجل outbox داخل العملية', () async {
      const account = Account(
        id: 'cash-1',
        name: 'الصندوق',
        type: AccountType.cash,
        openingBalance: Money(12500),
      );

      final result = await repository.create(account);

      expect(result.isOk, isTrue);
      final saved = await db.accountsDao.getById('cash-1');
      expect(saved?.name, 'الصندوق');
      expect(saved?.openingBalance, 12500);

      final outbox = await db.outboxDao.getPending();
      expect(outbox, hasLength(1));
      expect(outbox.single.entity, 'accounts');
      expect(outbox.single.entityId, 'cash-1');
      expect(outbox.single.operation, OutboxOperation.create);

      final payload = jsonDecode(outbox.single.payload) as Map<String, dynamic>;
      expect(payload['id'], 'cash-1');
      expect(payload['name'], 'الصندوق');
      expect(payload['opening_balance'], 12500);
    });

    test('يرفض الاسم الفارغ ولا يكتب شيئًا', () async {
      final result = await repository.create(
        makeAccount(id: 'invalid-1', name: '   '),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(await db.accountsDao.getById('invalid-1'), isNull);
      expect(await db.outboxDao.getPending(), isEmpty);
    });
  });

  group('تعديل وأرشفة الحساب', () {
    test('يحدّث الحساب وينشئ سجل outbox للتعديل', () async {
      await addAccount(db, name: 'قبل');

      final result = await repository.update(
        makeAccount(id: 'acc-قبل', name: 'بعد', openingBalance: const Money(500)),
      );

      expect(result.isOk, isTrue);
      expect((await db.accountsDao.getById('acc-قبل'))?.name, 'بعد');

      final outbox = await db.outboxDao.getPending();
      expect(outbox, hasLength(1));
      expect(outbox.single.operation, OutboxOperation.update);
      expect(outbox.single.entityId, 'acc-قبل');
    });

    test('يؤرشف الحساب ويخفيه من الحسابات النشطة', () async {
      await addAccount(db, name: 'أرشيف');
   const id = 'acc-أرشيف';
      final result = await repository.archive(id);

      expect(result.isOk, isTrue);
      expect(await db.accountsDao.getById(id), isNotNull);
      expect(await db.accountsDao.watchActive().first, isEmpty);
      expect((await db.outboxDao.getPending()).single.operation,
          OutboxOperation.update);
    });
  });

  group('الحذف الناعم', () {
    test('يحذف حسابًا غير مرتبط بعملية حذفًا ناعمًا ويسجله في outbox',
        () async {
      await addAccount(db, name: 'للحذف');
      const id = 'acc-للحذف';

      final result = await repository.softDelete(id);

      expect(result.isOk, isTrue);
      expect(await db.accountsDao.getById(id), isNull);

      final outbox = await db.outboxDao.getPending();
      expect(outbox, hasLength(1));
      expect(outbox.single.operation, OutboxOperation.delete);

      final deleted = await (db.select(db.accounts)
            ..where((account) => account.id.equals(id)))
          .getSingle();
      expect(deleted.deletedAt, isNotNull);
    });

    test('يرفض حذف حسابًا مرتبطًا بعملية فعّالة', () async {
      final accountId = await addAccount(db, name: 'مرتبط');

      await db.into(db.transactions).insert(
          TransactionsCompanion.insert(

              id: const Value('income-1'),
              type: db_transactions.TransactionType.income,
              date: DateTime.utc(2026, 11, 9),
              accountId: accountId,
              total: 1000,
              paidAmount: 1000,
            ),
          );

      final result = await repository.softDelete(accountId);

      expect(result.failureOrNull, isA<ConflictFailure>());
      expect(await db.accountsDao.getById(accountId), isNotNull);
      expect(await db.outboxDao.getPending(), isEmpty);
    });
  });

  group('الرصيد المشتق', () {
    test('يحسب الرصيد الافتتاحي وحركة الدخل المدفوعة فعليًا', () async {
      final accountId = await addAccount(
        db,
        name: 'الرصيد',
        opening: 10000,
      );

      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: const Value('income-partial'),
              type: db_transactions.TransactionType.income,
              date: DateTime.utc(2026, 11, 9),
              accountId: accountId,
              total: 5000,
              paidAmount: 3000,
            ),
          );

      final result = await repository.getBalance(accountId);

      expect(result.valueOrNull, const Money(13000));
    });

    test('يحتسب التحويل الوارد والصادر على الحسابين', () async {
      final sourceId = await addAccount(db, name: 'مصدر', opening: 10000);
      final targetId = await addAccount(db, name: 'وجهة', opening: 2000);

      await db.into(db.transactions).insert(
           TransactionsCompanion.insert(

              id: const Value('transfer-1'),
              type: db_transactions.TransactionType.transfer,
              date: DateTime.utc(2026, 11, 9),
              accountId: sourceId,
              toAccountId: Value(targetId),
              total: 3000,
              paidAmount: 3000,
            ),
          );

      final sourceBalance = await repository.getBalance(sourceId);
      final targetBalance = await repository.getBalance(targetId);

      expect(sourceBalance.valueOrNull, const Money(7000));
      expect(targetBalance.valueOrNull, const Money(5000));
    });
  });
}
