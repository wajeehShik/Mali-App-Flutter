import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/outbox_table.dart';
import 'package:mali/core/errors/failure.dart';
import 'package:mali/features/contacts/data/contact_repository_impl.dart';
import 'package:mali/features/contacts/domain/contact.dart';

import '../../../core/database/database_test_helper.dart';

void main() {
  late AppDatabase db;
  late ContactRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = ContactRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  Contact makeContact({
    String id = 'contact-1',
    String name = 'أحمد',
    ContactKind kind = ContactKind.customer,
    String? phone = '0599123456',
    String? note,
  }) {
    return Contact(
      id: id,
      name: name,
      kind: kind,
      phone: phone,
      note: note,
    );
  }

  group('create', () {
    test('يحفظ جهة الاتصال ويسجل outbox داخل المعاملة', () async {
      final result = await repository.create(
        makeContact(note: 'عميل دائم'),
      );

      expect(result.isOk, isTrue);
      final saved = await db.contactsDao.getById('contact-1');
      expect(saved?.name, 'أحمد');
      expect(saved?.phone, '0599123456');
      expect(saved?.note, 'عميل دائم');

      final outbox = await db.outboxDao.getPending();
      expect(outbox, hasLength(1));
      expect(outbox.single.entity, 'contacts');
      expect(outbox.single.entityId, 'contact-1');
      expect(outbox.single.operation, OutboxOperation.create);

      final payload = jsonDecode(outbox.single.payload) as Map<String, dynamic>;
      expect(payload['kind'], 'customer');
      expect(payload['name'], 'أحمد');
    });

    test('يرفض الاسم الفارغ دون كتابة جهة أو outbox', () async {
      final result = await repository.create(makeContact(name: '  '));

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(await db.contactsDao.getById('contact-1'), isNull);
      expect(await db.outboxDao.getPending(), isEmpty);
    });

    test('فشل إدخال outbox يلغي إدخال جهة الاتصال', () async {
      await db.customStatement('''
        CREATE TRIGGER reject_contact_outbox
        BEFORE INSERT ON outbox
        BEGIN
          SELECT RAISE(ABORT, 'outbox unavailable');
        END
      ''');

      final result = await repository.create(makeContact());

      expect(result.isErr, isTrue);
      expect(await db.contactsDao.getById('contact-1'), isNull);
      expect(await db.outboxDao.getPending(), isEmpty);
    });
  });

  group('القراءة والبحث', () {
    test('both تظهر في تدفقي العملاء والموردين', () async {
      await repository.create(
        makeContact(id: 'both-1', kind: ContactKind.both),
      );

      final customers = await repository.watchCustomers().first;
      final suppliers = await repository.watchSuppliers().first;

      expect(customers.map((contact) => contact.id), contains('both-1'));
      expect(suppliers.map((contact) => contact.id), contains('both-1'));
    });

    test('يبحث بالاسم أو الهاتف', () async {
      await repository.create(makeContact());

      final byName = await repository.search('أحم');
      final byPhone = await repository.search('0599');
      final absent = await repository.search('غير موجود');

      expect(byName.valueOrNull?.map((contact) => contact.id), ['contact-1']);
      expect(byPhone.valueOrNull?.map((contact) => contact.id), ['contact-1']);
      expect(absent.valueOrNull, isEmpty);
    });
  });

  group('update', () {
    test('يحدّث الحقول ويسمح بمسح الهاتف والملاحظة', () async {
      await repository.create(makeContact(note: 'قديم'));

      final result = await repository.update(
        makeContact(
          name: 'أحمد علي',
          kind: ContactKind.both,
          phone: null,
          note: null,
        ),
      );

      expect(result.isOk, isTrue);
      final updated = await db.contactsDao.getById('contact-1');
      expect(updated?.name, 'أحمد علي');
      expect(updated?.kind.name, 'both');
      expect(updated?.phone, isNull);
      expect(updated?.note, isNull);

      final outbox = await db.outboxDao.getPending();
      expect(outbox, hasLength(2));
      expect(outbox.last.operation, OutboxOperation.update);
    });

    test('يرجع NotFound عند تعديل جهة غير موجودة', () async {
      final result = await repository.update(makeContact(id: 'missing'));

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(await db.outboxDao.getPending(), isEmpty);
    });
  });

  group('softDelete', () {
    test('يحذف حذفًا ناعمًا ويسجل outbox', () async {
      await repository.create(makeContact());

      final result = await repository.softDelete('contact-1');

      expect(result.isOk, isTrue);
      expect(await db.contactsDao.getById('contact-1'), isNull);

      final outbox = await db.outboxDao.getPending();
      expect(outbox, hasLength(2));
      expect(outbox.last.operation, OutboxOperation.delete);
    });

    test('يرجع NotFound عند حذف جهة غير موجودة', () async {
      final result = await repository.softDelete('missing');

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(await db.outboxDao.getPending(), isEmpty);
    });
  });
}
