import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/outbox_table.dart';
import 'package:mali/core/database/tables/transactions_table.dart'
    as db_transactions;
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/sales/data/sale_repository_impl.dart';
import 'package:mali/features/sales/domain/sale.dart';

import '../../../core/database/database_test_helper.dart';

void main() {
  late AppDatabase db;
  late SaleRepositoryImpl repository;
  late String accountId;
  late String productId;

  setUp(() async {
    db = createTestDatabase();
    repository = SaleRepositoryImpl(db);
    accountId = await addAccount(db);
    productId = await addProduct(db, name: 'شاي');
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addStock(int quantity) async {
    final transactionId = 'purchase-stock-$quantity';

    await db.transactionsDao.insertWithItems(
      TransactionsCompanion.insert(
        id: Value(transactionId),
        type: db_transactions.TransactionType.purchase,
        date: DateTime.utc(2026, 11, 8),
        accountId: accountId,
        total: quantity,
        paidAmount: quantity,
      ),
      [
        TransactionItemsCompanion.insert(
          transactionId: transactionId,
          productId: productId,
          quantity: quantity,
          unitPrice: 100,
          unitCost: const Value(80),
        ),
      ],
    );
  }

  Sale makeSale({
    String id = 'sale-1',
    int quantity = 1000,
    int unitPrice = 100,
    int unitCost = 80,
  }) {
    final lineTotal = Money((unitPrice * quantity + 500) ~/ 1000);

    return Sale(
      id: id,
      date: DateTime.utc(2026, 11, 9),
      accountId: accountId,
      total: lineTotal,
      paidAmount: lineTotal,
      items: [
        SaleItem(
          productId: productId,
          quantityMilli: quantity,
          unitPrice: Money(unitPrice),
          unitCost: Money(unitCost),
        ),
      ],
    );
  }

  test('يرفض البيع عندما تكون الكمية المطلوبة أكبر من المخزون', () async {
    await addStock(1500);

    final result = await repository.create(makeSale(quantity: 2000));

    expect(result.failureOrNull, isA<ConflictFailure>());
    expect(await db.transactionsDao.getById('sale-1'), isNull);
    expect(await db.transactionsDao.getItems('sale-1'), isEmpty);
    expect(await db.outboxDao.getPending(), isEmpty);
  });

  test('يحفظ البيع وبنوده ويسجل outbox عندما يكون المخزون كافيًا', () async {
    await addStock(3000);

    final result = await repository.create(
      makeSale(quantity: 1500, unitPrice: 200),
    );

    expect(result.isOk, isTrue);

    final saved = await db.transactionsDao.getById('sale-1');
    expect(saved?.type.name, 'sale');
    expect(saved?.total, 300);
    expect(saved?.paidAmount, 300);

    final items = await db.transactionsDao.getItems('sale-1');
    expect(items, hasLength(1));
    expect(items.single.quantity, 1500);
    expect(items.single.unitPrice, 200);
    expect(items.single.unitCost, 80);

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(1));
    expect(outbox.single.entity, 'transactions');
    expect(outbox.single.entityId, 'sale-1');
    expect(outbox.single.operation, OutboxOperation.create);
  });

  test('فشل إدخال outbox يلغي البيع وبنوده معًا', () async {
    await addStock(3000);

    await db.customStatement('''
      CREATE TRIGGER reject_sale_outbox
      BEFORE INSERT ON outbox
      WHEN NEW.entity = 'transactions'
      BEGIN
        SELECT RAISE(ABORT, 'outbox unavailable');
      END
    ''');

    final result = await repository.create(makeSale());

    expect(result.isErr, isTrue);
    expect(await db.transactionsDao.getById('sale-1'), isNull);
    expect(await db.transactionsDao.getItems('sale-1'), isEmpty);
    expect(await db.outboxDao.getPending(), isEmpty);
  });

  test('يستثني البيع الحالي عند تعديله حتى لا تخصم كميته مرتين', () async {
    await addStock(3000);
    await repository.create(makeSale(quantity: 1000));

    final result = await repository.update(makeSale(quantity: 2500));

    expect(result.isOk, isTrue);

    final items = await db.transactionsDao.getItems('sale-1');
    expect(items, hasLength(1));
    expect(items.single.quantity, 2500);

    final refreshed = await repository.getById('sale-1');
    expect(refreshed.unwrap()?.items.single.quantityMilli, 2500);
  });

  test('يعيد عملية البيع مع بنودها', () async {
    await addStock(2000);
    await repository.create(makeSale(quantity: 1000));

    final result = await repository.getById('sale-1');

    expect(result.unwrap()?.items, hasLength(1));
    expect(result.unwrap()?.items.single.lineTotal, const Money(100));
  });
}
