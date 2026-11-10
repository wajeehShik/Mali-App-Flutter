import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/transactions_table.dart'
    as db_transactions;
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/transactions/data/transaction_repository_impl.dart';
import 'package:mali/features/transactions/domain/transaction_entry.dart';

import '../../../core/database/database_test_helper.dart';

void main() {
  late AppDatabase db;
  late TransactionRepositoryImpl repository;
  late String accountId;
  late String otherAccountId;
  late String productId;

  setUp(() async {
    db = createTestDatabase();
    repository = TransactionRepositoryImpl(db);
    accountId = await addAccount(db, name: 'الصندوق');
    otherAccountId = await addAccount(db, name: 'البنك');
    productId = await addProduct(db, name: 'دفتر');
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addTransaction({
    required String id,
    required db_transactions.TransactionType type,
    required DateTime date,
    required String account,
    required int total,
    int paidAmount = 0,
    String? note,
    String? toAccount,
    List<TransactionItemsCompanion> items = const [],
  }) async {
    await db.transactionsDao.insertWithItems(
      TransactionsCompanion.insert(
        id: Value(id),
        type: type,
        date: date,
        accountId: account,
        toAccountId: Value(toAccount),
        total: total,
        paidAmount: paidAmount,
        note: Value(note),
      ),
      items,
    );
  }

  test('يجلب المعاملات حسب النوع والحساب والمدى الزمني', () async {
    await addTransaction(
      id: 'income-1',
      type: db_transactions.TransactionType.income,
      date: DateTime.utc(2026, 11, 5),
      account: accountId,
      total: 5000,
      paidAmount: 5000,
    );
    await addTransaction(
      id: 'expense-1',
      type: db_transactions.TransactionType.expense,
      date: DateTime.utc(2026, 11, 7),
      account: accountId,
      total: 1000,
      paidAmount: 1000,
    );
    await addTransaction(
      id: 'income-2',
      type: db_transactions.TransactionType.income,
      date: DateTime.utc(2026, 11, 9),
      account: otherAccountId,
      total: 7000,
      paidAmount: 7000,
    );

    final result = await repository.getTransactions(
      from: DateTime.utc(2026, 11, 6),
      to: DateTime.utc(2026, 11, 9),
      type: FinancialTransactionType.expense,
      accountId: accountId,
    );

    final entries = result.unwrap();
    expect(entries, hasLength(1));
    expect(entries.single.id, 'expense-1');
    expect(entries.single.total, const Money(1000));
  });

  test('يشمل فلتر الحساب تحويلًا يكون فيه الحساب هو الوجهة', () async {
    await addTransaction(
      id: 'transfer-1',
      type: db_transactions.TransactionType.transfer,
      date: DateTime.utc(2026, 11, 9),
      account: accountId,
      toAccount: otherAccountId,
      total: 2500,
      paidAmount: 2500,
    );

    final result = await repository.getTransactions(
      accountId: otherAccountId,
    );

    expect(result.unwrap(), hasLength(1));
    expect(result.unwrap().single.id, 'transfer-1');
  });

  test('يجلب البيع مع تفاصيل بنود المنتجات', () async {
    await addTransaction(
      id: 'sale-1',
      type: db_transactions.TransactionType.sale,
      date: DateTime.utc(2026, 11, 9),
      account: accountId,
      total: 3600,
      paidAmount: 2000,
      items: [
        TransactionItemsCompanion.insert(
          transactionId: 'sale-1',
          productId: productId,
          quantity: 1500,
          unitPrice: 2400,
          unitCost: const Value(1800),
        ),
      ],
    );

    final result = await repository.getById('sale-1');
    final entry = result.unwrap();

    expect(entry?.type, FinancialTransactionType.sale);
    expect(entry?.items, hasLength(1));
    expect(entry?.items.single.productId, productId);
    expect(entry?.items.single.quantityMilli, 1500);
    expect(entry?.items.single.lineTotal, const Money(3600));
    expect(entry?.remainingAmount, const Money(1600));
  });

  test('يبحث برقم المعاملة أو الملاحظة مع فلتر النوع', () async {
    await addTransaction(
      id: 'income-123',
      type: db_transactions.TransactionType.income,
      date: DateTime.utc(2026, 11, 9),
      account: accountId,
      total: 4200,
      paidAmount: 4200,
      note: 'دفعة إيجار',
    );
    await addTransaction(
      id: 'expense-456',
      type: db_transactions.TransactionType.expense,
      date: DateTime.utc(2026, 11, 9),
      account: accountId,
      total: 900,
      paidAmount: 900,
      note: 'مستلزمات',
    );

    final result = await repository.search(
      'إيجار',
      type: FinancialTransactionType.income,
    );

    expect(result.unwrap(), hasLength(1));
    expect(result.unwrap().single.id, 'income-123');
  });

  test('لا يعيد معاملة محذوفة أو غير موجودة', () async {
    await addTransaction(
      id: 'income-deleted',
      type: db_transactions.TransactionType.income,
      date: DateTime.utc(2026, 11, 9),
      account: accountId,
      total: 1000,
      paidAmount: 1000,
    );

    await db.transactionsDao.softDelete('income-deleted');

    final result = await repository.getById('income-deleted');

    expect(result.unwrap(), isNull);
  });
}
