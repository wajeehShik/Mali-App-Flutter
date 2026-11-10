import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/contacts_table.dart' as db_contacts;
import 'package:mali/core/database/tables/outbox_table.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/purchases/data/purchase_repository_impl.dart';
import 'package:mali/features/purchases/domain/purchase.dart';

import '../../../core/database/database_test_helper.dart';

void main() {
  late AppDatabase db;
  late PurchaseRepositoryImpl repository;
  late String accountId;
  late String productId;
  late String supplierId;

  setUp(() async {
    db = createTestDatabase();
    repository = PurchaseRepositoryImpl(db);
    accountId = await addAccount(db);
    productId = await addProduct(db, name: 'قهوة');
    supplierId = await addContact(
      db,
      name: 'المورد',
      kind: db_contacts.ContactKind.supplier,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Purchase makePurchase({
    String id = 'purchase-1',
    Money total = const Money(1800),
    Money paidAmount = const Money(900),
    String? note = 'شراء مخزون',
    List<PurchaseItem>? items,
  }) {
    return Purchase(
      id: id,
      date: DateTime.utc(2026, 11, 9),
      accountId: accountId,
      supplierId: supplierId,
      total: total,
      paidAmount: paidAmount,
      note: note,
      items: items ??
          [
            PurchaseItem(
              productId: productId,
              quantityMilli: 1500,
              unitPrice: const Money(1200),
              unitCost: const Money(900),
            ),
          ],
    );
  }

  test('ينشئ عملية الشراء وبنودها ويسجل outbox ذريًا', () async {
    final result = await repository.create(makePurchase());

    expect(result.isOk, isTrue);

    final saved = await db.transactionsDao.getById('purchase-1');
    expect(saved?.type.name, 'purchase');
    expect(saved?.accountId, accountId);
    expect(saved?.contactId, supplierId);
    expect(saved?.total, 1800);
    expect(saved?.paidAmount, 900);

    final items = await db.transactionsDao.getItems('purchase-1');
    expect(items, hasLength(1));
    expect(items.single.productId, productId);
    expect(items.single.quantity, 1500);
    expect(items.single.unitPrice, 1200);
    expect(items.single.unitCost, 900);

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(1));
    expect(outbox.single.entity, 'transactions');
    expect(outbox.single.entityId, 'purchase-1');
    expect(outbox.single.operation, OutboxOperation.create);

    final payload = jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(payload['type'], 'purchase');
    expect(payload['total'], 1800);
    expect(payload['items'], hasLength(1));
    expect(payload['items'].single['product_id'], productId);
  });

  test('يرجع عملية الشراء مع بنودها', () async {
    await repository.create(makePurchase());

    final result = await repository.getById('purchase-1');
    final purchase = result.unwrap();

    expect(purchase?.id, 'purchase-1');
    expect(purchase?.items, hasLength(1));
    expect(purchase?.items.single.quantityMilli, 1500);
    expect(purchase?.items.single.lineTotal, const Money(1800));
  });

  test('يرفض إجماليًا لا يساوي مجموع البنود', () async {
    final result = await repository.create(
      makePurchase(total: const Money(2000)),
    );

    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(await db.transactionsDao.getById('purchase-1'), isNull);
    expect(await db.outboxDao.getPending(), isEmpty);
  });

  test('فشل إدخال outbox يلغي العملية وبنودها معًا', () async {
    await db.customStatement('''
      CREATE TRIGGER reject_purchase_outbox
      BEFORE INSERT ON outbox
      WHEN NEW.entity = 'transactions'
      BEGIN
        SELECT RAISE(ABORT, 'outbox unavailable');
      END
    ''');

    final result = await repository.create(makePurchase());

    expect(result.isErr, isTrue);
    expect(await db.transactionsDao.getById('purchase-1'), isNull);
    expect(await db.transactionsDao.getItems('purchase-1'), isEmpty);
    expect(await db.outboxDao.getPending(), isEmpty);
  });

  test('يعدّل العملية وبنودها ويسجل update في outbox', () async {
    await repository.create(makePurchase());

    final result = await repository.update(
      makePurchase(
        total: const Money(2000),
        paidAmount: const Money(2000),
        note: 'تم تحديث الشراء',
        items: [
          PurchaseItem(
            productId: productId,
            quantityMilli: 2000,
            unitPrice: const Money(1000),
            unitCost: const Money(800),
          ),
        ],
      ),
    );

    expect(result.isOk, isTrue);

    final saved = await db.transactionsDao.getById('purchase-1');
    expect(saved?.total, 2000);
    expect(saved?.note, 'تم تحديث الشراء');

    final items = await db.transactionsDao.getItems('purchase-1');
    expect(items, hasLength(1));
    expect(items.single.quantity, 2000);
    expect(items.single.unitPrice, 1000);

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(2));
    expect(outbox.last.operation, OutboxOperation.update);
  });

  test('يحذف العملية وبنودها حذفًا ناعمًا ويسجل delete في outbox', () async {
    await repository.create(makePurchase());

    final result = await repository.softDelete('purchase-1');

    expect(result.isOk, isTrue);
    expect(await db.transactionsDao.getById('purchase-1'), isNull);
    expect(await db.transactionsDao.getItems('purchase-1'), isEmpty);

    final outbox = await db.outboxDao.getPending();
    expect(outbox, hasLength(2));
    expect(outbox.last.operation, OutboxOperation.delete);
  });
}
