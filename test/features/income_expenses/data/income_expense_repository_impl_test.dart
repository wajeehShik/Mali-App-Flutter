import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/outbox_table.dart';
import 'package:mali/core/database/tables/transactions_table.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/income_expenses/data/income_expense_repository_impl.dart';
import 'package:mali/features/income_expenses/domain/income_expense.dart';

import '../../../core/database/database_test_helper.dart';

void main() {
  late AppDatabase db;
  late IncomeExpenseRepositoryImpl repository;
  late String accountId;

  setUp(() async {
    db = createTestDatabase();
    repository = IncomeExpenseRepositoryImpl(db);
    accountId = await addAccount(db);
  });

  tearDown(() async {
    await db.close();
  });

  IncomeExpense makeEntry({
    String id = 'income-expense-1',
    IncomeExpenseType type = IncomeExpenseType.income,
    Money amount = const Money(2500),
    DateTime? date,
    String? categoryId,
    String? note,
  }) {
    return IncomeExpense(
      id: id,
      type: type,
      date: date ?? DateTime.utc(2026, 11, 9),
      accountId: accountId,
      amount: amount,
      categoryId: categoryId,
      note: note,
    );
  }

  test('ينشئ إيرادًا ويسجل outbox مع بيانات العملية', () async {
    final result = await repository.create(
      makeEntry(note: 'دفعة نقدية'),
    );

    expect(result.isOk, isTrue);

    final saved = await db.transactionsDao.getById('income-expense-1');
    expect(saved?.type, TransactionType.income);
    expect(saved?.accountId, accountId);
    expect(saved?.total, 2500);
    expect(saved?.paidAmount, 2500);
    expect(saved?.note, 'دفعة نقدية');

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(1));
    expect(outbox.single.entity, 'transactions');
    expect(outbox.single.entityId, 'income-expense-1');
    expect(outbox.single.operation, OutboxOperation.create);

    final payload = jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(payload['type'], 'income');
    expect(payload['total'], 2500);
    expect(payload['note'], 'دفعة نقدية');
  });

  test('يرفض المبلغ الصفري دون حفظ العملية أو outbox', () async {
    final result = await repository.create(
      makeEntry(amount: Money.zero),
    );

    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(await db.transactionsDao.getById('income-expense-1'), isNull);
    expect(await db.outboxDao.getPending(), isEmpty);
  });

  test('فشل إدخال outbox يلغي إنشاء العملية ضمن المعاملة نفسها', () async {
    await db.customStatement('''
      CREATE TRIGGER reject_transaction_outbox
      BEFORE INSERT ON outbox
      WHEN NEW.entity = 'transactions'
      BEGIN
        SELECT RAISE(ABORT, 'outbox unavailable');
      END
    ''');

    final result = await repository.create(makeEntry());

    expect(result.isErr, isTrue);
    expect(await db.transactionsDao.getById('income-expense-1'), isNull);
    expect(await db.outboxDao.getPending(), isEmpty);
  });

  test('يعيد الحركة عند الجلب ويبحث في الملاحظة', () async {
    await repository.create(
      makeEntry(note: 'إيجار المكتب'),
    );

    final byId = await repository.getById('income-expense-1');
    final bySearch = await repository.search('إيجار');

    expect(byId.unwrap()?.amount, const Money(2500));
    expect(byId.unwrap()?.type, IncomeExpenseType.income);
    expect(
      bySearch.unwrap().map((entry) => entry.id),
      ['income-expense-1'],
    );
  });

  test('يحدّث الحركة ويسجل عملية update في outbox', () async {
    await repository.create(makeEntry(note: 'قديم'));

    final result = await repository.update(
      makeEntry(
        type: IncomeExpenseType.expense,
        amount: const Money(4200),
        note: 'مصروف جديد',
      ),
    );

    expect(result.isOk, isTrue);

    final saved = await db.transactionsDao.getById('income-expense-1');
    expect(saved?.type, TransactionType.expense);
    expect(saved?.total, 4200);
    expect(saved?.note, 'مصروف جديد');

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(2));
    expect(outbox.last.operation, OutboxOperation.update);
  });

  test('يحذف الحركة حذفًا ناعمًا ويسجل delete في outbox', () async {
    await repository.create(makeEntry());

    final result = await repository.softDelete('income-expense-1');

    expect(result.isOk, isTrue);
    expect(await db.transactionsDao.getById('income-expense-1'), isNull);

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(2));
    expect(outbox.last.operation, OutboxOperation.delete);
  });

  test('مراقبة النوع لا تخلط الإيرادات بالمصروفات', () async {
    await repository.create(
      makeEntry(id: 'income-1', type: IncomeExpenseType.income),
    );
    await repository.create(
      makeEntry(
        id: 'expense-1',
        type: IncomeExpenseType.expense,
        amount: const Money(800),
      ),
    );

    final incomes = await repository
        .watchByType(IncomeExpenseType.income)
        .first;
    final expenses = await repository
        .watchByType(IncomeExpenseType.expense)
        .first;

    expect(incomes.map((entry) => entry.id), ['income-1']);
    expect(expenses.map((entry) => entry.id), ['expense-1']);
  });
}
