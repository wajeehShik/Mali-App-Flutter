import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/contacts_table.dart' as db_contacts;
import 'package:mali/core/database/tables/outbox_table.dart';
import 'package:mali/core/database/tables/transactions_table.dart'
    as db_transactions;
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/debts/data/debt_repository_impl.dart';
import 'package:mali/features/debts/domain/debt_balance.dart';
import 'package:mali/features/debts/domain/debt_payment.dart';

import '../../../core/database/database_test_helper.dart';

void main() {
  late AppDatabase db;
  late DebtRepositoryImpl repository;
  late String accountId;
  late String customerId;
  late String supplierId;

  setUp(() async {
    db = createTestDatabase();
    repository = DebtRepositoryImpl(db);
    accountId = await addAccount(db);

    customerId = await addContact(
      db,
      name: 'عميل الدين',
      kind: db_contacts.ContactKind.customer,
    );

    supplierId = await addContact(
      db,
      name: 'مورد الدين',
      kind: db_contacts.ContactKind.supplier,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addTransaction({
    required String id,
    required String contactId,
    required db_transactions.TransactionType type,
    required int total,
    required int paidAmount,
  }) async {
    await db.transactionsDao.insertWithItems(
      TransactionsCompanion.insert(
        id: Value(id),
        type: type,
        date: DateTime.utc(2026, 11, 9),
        accountId: accountId,
        contactId: Value(contactId),
        total: total,
        paidAmount: paidAmount,
      ),
      [],
    );
  }

  test('يحسب رصيد العميل من الجزء غير المدفوع للبيع', () async {
    await addTransaction(
      id: 'sale-debt',
      contactId: customerId,
      type: db_transactions.TransactionType.sale,
      total: 10000,
      paidAmount: 2500,
    );

    final result = await repository.getBalance(
      customerId,
      DebtDirection.receivable,
    );

    expect(result.isOk, isTrue);
    expect(result.unwrap()?.amount, const Money(7500));
  });

  test('يسجل تحصيل العميل ويقلل الدين ويسجل outbox', () async {
    await addTransaction(
      id: 'sale-debt',
      contactId: customerId,
      type: db_transactions.TransactionType.sale,
      total: 10000,
      paidAmount: 2500,
    );

    final result = await repository.recordPayment(
      DebtPayment(
        id: 'payment-in',
        date: DateTime.utc(2026, 11, 9),
        accountId: accountId,
        contactId: customerId,
        direction: DebtDirection.receivable,
        amount: const Money(3000),
        note: 'دفعة من العميل',
      ),
    );

    expect(result.isOk, isTrue);

    final saved = await db.transactionsDao.getById('payment-in');
    expect(saved?.type, db_transactions.TransactionType.debtIn);
    expect(saved?.contactId, customerId);
    expect(saved?.total, 3000);
    expect(saved?.paidAmount, 3000);

    final balance = await repository.getBalance(
      customerId,
      DebtDirection.receivable,
    );
    expect(balance.unwrap()?.amount, const Money(4500));

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(1));
    expect(outbox.single.entityId, 'payment-in');
    expect(outbox.single.operation, OutboxOperation.create);
  });

  test('يسجل سداد المورد كـ debtOut ويقلل الرصيد المستحق', () async {
    await addTransaction(
      id: 'purchase-debt',
      contactId: supplierId,
      type: db_transactions.TransactionType.purchase,
      total: 9000,
      paidAmount: 1000,
    );

    final result = await repository.recordPayment(
      DebtPayment(
        id: 'payment-out',
        date: DateTime.utc(2026, 11, 9),
        accountId: accountId,
        contactId: supplierId,
        direction: DebtDirection.payable,
        amount: const Money(2000),
      ),
    );

    expect(result.isOk, isTrue);

    final saved = await db.transactionsDao.getById('payment-out');
    expect(saved?.type, db_transactions.TransactionType.debtOut);

    final balance = await repository.getBalance(
      supplierId,
      DebtDirection.payable,
    );
    expect(balance.unwrap()?.amount, const Money(6000));
  });

  test('يرفض مبلغ سداد أكبر من الدين ولا يسجل عملية أو outbox', () async {
    await addTransaction(
      id: 'sale-debt',
      contactId: customerId,
      type: db_transactions.TransactionType.sale,
      total: 5000,
      paidAmount: 1000,
    );

    final result = await repository.recordPayment(
      DebtPayment(
        id: 'too-much',
        date: DateTime.utc(2026, 11, 9),
        accountId: accountId,
        contactId: customerId,
        direction: DebtDirection.receivable,
        amount: const Money(5000),
      ),
    );

    expect(result.failureOrNull, isA<ConflictFailure>());
    expect(await db.transactionsDao.getById('too-much'), isNull);
    expect(await db.outboxDao.getPending(), isEmpty);
  });

  test('فشل كتابة outbox يلغي عملية السداد', () async {
    await addTransaction(
      id: 'sale-debt',
      contactId: customerId,
      type: db_transactions.TransactionType.sale,
      total: 5000,
      paidAmount: 1000,
    );

    await db.customStatement('''
      CREATE TRIGGER reject_debt_payment_outbox
      BEFORE INSERT ON outbox
      WHEN NEW.entity = 'transactions'
      BEGIN
        SELECT RAISE(ABORT, 'outbox unavailable');
      END
    ''');

    final result = await repository.recordPayment(
      DebtPayment(
        id: 'payment-fail',
        date: DateTime.utc(2026, 11, 9),
        accountId: accountId,
        contactId: customerId,
        direction: DebtDirection.receivable,
        amount: const Money(1000),
      ),
    );

    expect(result.isErr, isTrue);
    expect(await db.transactionsDao.getById('payment-fail'), isNull);
    expect(await db.outboxDao.getPending(), isEmpty);

    final balance = await repository.getBalance(
      customerId,
      DebtDirection.receivable,
    );
    expect(balance.unwrap()?.amount, const Money(4000));
  });
}
