import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/transactions_table.dart';
import 'package:mali/features/inventory/data/inventory_repository_impl.dart';

import '../../../core/database/database_test_helper.dart';

void main() {
  late AppDatabase db;
  late InventoryRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = InventoryRepositoryImpl(db);
  });

  tearDown(() => db.close());

  Future<void> addTransaction({
    required String id,
    required String accountId,
    required String productId,
    required TransactionType type,
    required int quantity,
  }) async {
    await db.transactionsDao.insertWithItems(
      TransactionsCompanion.insert(
        id: Value(id),
        type: type,
        date: DateTime.utc(2026, 11, 9),
        accountId: accountId,
        total: quantity,
        paidAmount: quantity,
      ),
      [
        TransactionItemsCompanion.insert(
          transactionId: id,
          productId: productId,
          quantity: quantity,
          unitPrice: 100,
        ),
      ],
    );
  }

  test('يحسب الرصيد من الشراء موجبًا والبيع سالبًا', () async {
    final accountId = await addAccount(db);
    final productId = await addProduct(db, name: 'طحين');

    await addTransaction(
      id: 'purchase-1',
      accountId: accountId,
      productId: productId,
      type: TransactionType.purchase,
      quantity: 3500,
    );
    await addTransaction(
      id: 'sale-1',
      accountId: accountId,
      productId: productId,
      type: TransactionType.sale,
      quantity: 1250,
    );

    final result = await repository.getBalance(productId);

    expect(result.isOk, isTrue);
    expect(result.unwrap()?.quantityMilli, 2250);
    expect(result.unwrap()?.product.name, 'طحين');
  });

  test(
    'يستثني العمليات المحذوفة ناعمًا ويُظهر المنتجات بلا حركة بصفر',
    () async {
      final accountId = await addAccount(db);
      final movedProductId = await addProduct(db, name: 'سكر');
      final emptyProductId = await addProduct(db, name: 'ملح');

      await addTransaction(
        id: 'purchase-deleted',
        accountId: accountId,
        productId: movedProductId,
        type: TransactionType.purchase,
        quantity: 5000,
      );
      await db.transactionsDao.softDelete('purchase-deleted');

      final movedResult = await repository.getBalance(movedProductId);
      final emptyResult = await repository.getBalance(emptyProductId);

      expect(movedResult.unwrap()?.quantityMilli, 0);
      expect(emptyResult.unwrap()?.quantityMilli, 0);
    },
  );

  test('يعرض المنتجات التي وصلت إلى حد المخزون أو نزلت عنه فقط', () async {
    final accountId = await addAccount(db);
    const lowProductId = 'prod-low';
    const normalProductId = 'prod-normal';

    await db.productsDao.insertProduct(
      ProductsCompanion.insert(
        id: const Value(lowProductId),
        name: 'مخزون منخفض',
        minStock: const Value(2000),
      ),
    );
    await db.productsDao.insertProduct(
      ProductsCompanion.insert(
        id: const Value(normalProductId),
        name: 'مخزون كافٍ',
        minStock: const Value(1000),
      ),
    );

    await addTransaction(
      id: 'purchase-low',
      accountId: accountId,
      productId: lowProductId,
      type: TransactionType.purchase,
      quantity: 1500,
    );
    await addTransaction(
      id: 'purchase-normal',
      accountId: accountId,
      productId: normalProductId,
      type: TransactionType.purchase,
      quantity: 2000,
    );

    final balances = await repository.watchBalances(lowStockOnly: true).first;

    expect(balances.map((balance) => balance.product.id), [lowProductId]);
  });
}
