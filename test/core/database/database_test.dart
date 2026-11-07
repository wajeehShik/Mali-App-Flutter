import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/contacts_table.dart';
import 'package:mali/core/database/tables/outbox_table.dart';

import 'package:mali/core/database/tables/transactions_table.dart';

import 'database_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  TransactionsCompanion saleTx(String id, String accountId) {
    return TransactionsCompanion.insert(
      id: Value(id),
      type: TransactionType.sale,
      date: DateTime.utc(2026, 11, 7),
      accountId: accountId,
      total: 1000,
      paidAmount: 1000,
    );
  }

  group('الحسابات', () {
    test('إضافة وقراءة وتعديل وحذف ناعم', () async {
      final id = await addAccount(db, name: 'الصندوق', opening: 500);

      final row = await db.accountsDao.getById(id);
      expect(row?.name, 'الصندوق');
      expect(row?.openingBalance, 500);
      expect(row?.currency, 'ILS');
      expect(row?.syncStatus, 'pending');

      final updated = await db.accountsDao
          .updateAccount(id, const AccountsCompanion(name: Value('البنك')));
      expect(updated, isTrue);
      expect((await db.accountsDao.getById(id))?.name, 'البنك');

      expect(await db.accountsDao.softDelete(id), isTrue);
      expect(await db.accountsDao.getById(id), isNull);
      expect(await db.accountsDao.getAll(), isEmpty);
      expect(await db.accountsDao.softDelete(id), isFalse);
    });
  });

  group('جهات الاتصال', () {
    test('both يظهر في العملاء والموردين', () async {
      await addContact(db, name: 'عميل', kind: ContactKind.customer);
      await addContact(db, name: 'مورد', kind: ContactKind.supplier);
      await addContact(db, name: 'كلاهما', kind: ContactKind.both);

      final customers = await db.contactsDao.watchCustomers().first;
      final suppliers = await db.contactsDao.watchSuppliers().first;

      expect(customers.map((c) => c.name).toSet(), {'عميل', 'كلاهما'});
      expect(suppliers.map((c) => c.name).toSet(), {'مورد', 'كلاهما'});
    });

    test('البحث بالاسم والهاتف', () async {
      await db.contactsDao.insertContact(
        ContactsCompanion.insert(
          name: 'سامي',
          kind: ContactKind.customer,
          phone: const Value('0599123456'),
        ),
      );
      expect((await db.contactsDao.search('سام')).length, 1);
      expect((await db.contactsDao.search('0599')).length, 1);
      expect(await db.contactsDao.search('زيد'), isEmpty);
    });
  });

  group('المنتجات', () {
    test('الجلب بالباركود يتجاهل غير النشط والمحذوف', () async {
      final id = await addProduct(db, name: 'قلم', barcode: '123');
      expect((await db.productsDao.getByBarcode('123'))?.id, id);

      await db.productsDao
          .updateProduct(id, const ProductsCompanion(isActive: Value(false)));
      expect(await db.productsDao.getByBarcode('123'), isNull);

      await db.productsDao
          .updateProduct(id, const ProductsCompanion(isActive: Value(true)));
      await db.productsDao.softDelete(id);
      expect(await db.productsDao.getByBarcode('123'), isNull);
    });
  });

  group('العمليات', () {
    test('حفظ عملية مع بنودها وقراءتها', () async {
      final acc = await addAccount(db);
      final prod = await addProduct(db);

      await db.transactionsDao.insertWithItems(
        saleTx('tx1', acc),
        [
          TransactionItemsCompanion.insert(
            transactionId: 'tx1',
            productId: prod,
            quantity: 1500,
            unitPrice: 400,
          ),
        ],
      );

      expect((await db.transactionsDao.getById('tx1'))?.total, 1000);
      final items = await db.transactionsDao.getItems('tx1');
      expect(items.length, 1);
      expect(items.first.quantity, 1500);
    });

    test('الذرّية: فشل بند يلغي العملية كلها', () async {
      final acc = await addAccount(db);

      // البند يشير إلى منتج غير موجود، فيكسر المفتاح الأجنبي.
      await expectLater(
        db.transactionsDao.insertWithItems(
          saleTx('tx2', acc),
          [
            TransactionItemsCompanion.insert(
              transactionId: 'tx2',
              productId: 'منتج-غير-موجود',
              quantity: 1000,
              unitPrice: 100,
            ),
          ],
        ),
        throwsA(anything),
      );

      expect(await db.transactionsDao.getById('tx2'), isNull);
    });

    test('الحذف الناعم يحذف العملية وبنودها معًا', () async {
      final acc = await addAccount(db);
      final prod = await addProduct(db);
      await db.transactionsDao.insertWithItems(
        saleTx('tx3', acc),
        [
          TransactionItemsCompanion.insert(
            transactionId: 'tx3',
            productId: prod,
            quantity: 1000,
            unitPrice: 100,
          ),
        ],
      );

      expect(await db.transactionsDao.softDelete('tx3'), isTrue);
      expect(await db.transactionsDao.getById('tx3'), isNull);
      expect(await db.transactionsDao.getItems('tx3'), isEmpty);
    });

    test('تعديل العملية يستبدل البنود', () async {
      final acc = await addAccount(db);
      final p1 = await addProduct(db, name: 'أ');
      final p2 = await addProduct(db, name: 'ب');
      await db.transactionsDao.insertWithItems(
        saleTx('tx4', acc),
        [
          TransactionItemsCompanion.insert(
            transactionId: 'tx4',
            productId: p1,
            quantity: 1000,
            unitPrice: 100,
          ),
        ],
      );

      final ok = await db.transactionsDao.updateWithItems(
        'tx4',
        const TransactionsCompanion(total: Value(2500), paidAmount: Value(2500)),
        [
          TransactionItemsCompanion.insert(
            transactionId: 'tx4',
            productId: p2,
            quantity: 2000,
            unitPrice: 1250,
          ),
        ],
      );

      expect(ok, isTrue);
      expect((await db.transactionsDao.getById('tx4'))?.total, 2500);
      final items = await db.transactionsDao.getItems('tx4');
      expect(items.length, 1);
      expect(items.first.productId, p2);
    });

    test('المدى الزمني: الحد الأعلى مستثنى', () async {
      final acc = await addAccount(db);
      await db.transactionsDao.insertWithItems(saleTx('in', acc), []);

      final inside = await db.transactionsDao
          .watchByDateRange(DateTime.utc(2026, 11, 7), DateTime.utc(2026, 11, 8))
          .first;
      final outside = await db.transactionsDao
          .watchByDateRange(DateTime.utc(2026, 11, 6), DateTime.utc(2026, 11, 7))
          .first;

      expect(inside.length, 1);
      expect(outside, isEmpty);
    });
  });

  group('الإعدادات', () {
    test('حفظ واستبدال وحذف', () async {
      expect(await db.settingsDao.getValue('currency'), isNull);
      await db.settingsDao.setValue('currency', 'ILS');
      await db.settingsDao.setValue('currency', 'USD');
      expect(await db.settingsDao.getValue('currency'), 'USD');
      expect(await db.settingsDao.getAll(), {'currency': 'USD'});
      await db.settingsDao.remove('currency');
      expect(await db.settingsDao.getValue('currency'), isNull);
    });
  });

  group('طابور المزامنة', () {
    test('الترتيب والعدّاد وmarkFailed والحذف', () async {
      final a = await db.outboxDao.enqueue(
        entity: 'transactions',
        entityId: '1',
        operation: OutboxOperation.create,
        payload: '{}',
      );
      await db.outboxDao.enqueue(
        entity: 'products',
        entityId: '2',
        operation: OutboxOperation.update,
        payload: '{}',
      );

      final pending = await db.outboxDao.getPending();
      expect(pending.map((e) => e.entity), ['transactions', 'products']);
      expect(await db.outboxDao.watchPendingCount().first, 2);

      await db.outboxDao.markFailed(a, 'no network');
      await db.outboxDao.markFailed(a, 'no network');
      final failed = (await db.outboxDao.getPending()).first;
      expect(failed.attempts, 2);
      expect(failed.lastError, 'no network');

      await db.outboxDao.remove(a);
      expect(await db.outboxDao.watchPendingCount().first, 1);
    });
  });

  group('الفهارس', () {
    test('أُنشئت الفهارس الثمانية', () async {
      final rows = await db
          .customSelect(
            'SELECT name FROM sqlite_master ' 
            "WHERE type = 'index' AND name LIKE 'idx_%'",
          )
          .get();
      expect(rows.length, 8);
    });
  });
}