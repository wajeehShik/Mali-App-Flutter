import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/contacts_table.dart' as db_contacts;
import '../../../core/database/tables/outbox_table.dart';
import '../../../core/errors/failure.dart';
import '../domain/contact.dart';
import '../domain/contact_repository.dart';

/// تنفيذ مستودع جهات الاتصال محليًا عبر Drift.
/// كل كتابة إلى contacts وسجل outbox المرتبط بها ذرّيان.
class ContactRepositoryImpl implements ContactRepository {
  ContactRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Contact>> watchCustomers() {
    return _db.contactsDao.watchCustomers().map(_mapRows);
  }

  @override
  Stream<List<Contact>> watchSuppliers() {
    return _db.contactsDao.watchSuppliers().map(_mapRows);
  }

  @override
  Future<Result<List<Contact>>> getAll() {
    return guardAsync(() async => _mapRows(await _db.contactsDao.getAll()));
  }

  @override
  Future<Result<List<Contact>>> search(String query) {
    return guardAsync(() async => _mapRows(await _db.contactsDao.search(query)));
  }

  @override
  Future<Result<Contact?>> getById(String id) {
    return guardAsync(() async {
      final row = await _db.contactsDao.getById(id);
      return row == null ? null : _fromRow(row);
    });
  }

  @override
  Future<Result<void>> create(Contact contact) {
    final failure = _validate(contact);
    if (failure != null) return Future.value(Err<void>(failure));

    return guardAsync(() async {
      await _db.transaction(() async {
        await _db.into(_db.contacts).insert(
              ContactsCompanion.insert(
                id: Value(contact.id),
                name: contact.name.trim(),
                kind: db_contacts.ContactKind.values.byName(contact.kind.name),
                phone: Value(_cleanOptional(contact.phone)),
                note: Value(_cleanOptional(contact.note)),
              ),
            );

        final row = await _readRow(contact.id);
        await _enqueue(
          row: row,
          operation: OutboxOperation.create,
        );
      });
    });
  }

  @override
  Future<Result<void>> update(Contact contact) {
    final failure = _validate(contact);
    if (failure != null) return Future.value(Err<void>(failure));

    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(contact.id);
        if (existing == null) {
          throw const FailureException(
            NotFoundFailure('جهة الاتصال غير موجودة.'),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.contacts)
              ..where((row) => row.id.equals(contact.id)))
            .write(
          ContactsCompanion(
            name: Value(contact.name.trim()),
            kind: Value(
              db_contacts.ContactKind.values.byName(contact.kind.name),
            ),
            phone: Value(_cleanOptional(contact.phone)),
            note: Value(_cleanOptional(contact.note)),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final row = await _readRow(contact.id);
        await _enqueue(row: row, operation: OutboxOperation.update);
      });
    });
  }

  @override
  Future<Result<void>> softDelete(String id) {
    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(id);
        if (existing == null) {
          throw const FailureException(
            NotFoundFailure('جهة الاتصال غير موجودة.'),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.contacts)..where((row) => row.id.equals(id)))
            .write(
          ContactsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final row = await _readRow(id);
        await _enqueue(row: row, operation: OutboxOperation.delete);
      });
    });
  }

  List<Contact> _mapRows(List<ContactRow> rows) =>
      rows.map(_fromRow).toList(growable: false);

  Contact _fromRow(ContactRow row) {
    return Contact(
      id: row.id,
      name: row.name,
      kind: ContactKind.values.byName(row.kind.name),
      phone: row.phone,
      note: row.note,
    );
  }

  Failure? _validate(Contact contact) {
    final errors = <String, String>{};
    final name = contact.name.trim();

    if (contact.id.trim().isEmpty) {
      errors['id'] = 'معرّف جهة الاتصال مطلوب.';
    }
    if (name.isEmpty) {
      errors['name'] = 'اسم جهة الاتصال مطلوب.';
    } else if (name.length > 100) {
      errors['name'] = 'اسم جهة الاتصال طويل جدًا.';
    }

    final phone = contact.phone?.trim();
    if (phone != null && phone.length > 30) {
      errors['phone'] = 'رقم الهاتف طويل جدًا.';
    }

    final note = contact.note?.trim();
    if (note != null && note.length > 500) {
      errors['note'] = 'الملاحظة طويلة جدًا.';
    }

    if (errors.isEmpty) return null;
    return ValidationFailure('تحقق من بيانات جهة الاتصال.', fieldErrors: errors);
  }

  String? _cleanOptional(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  Future<ContactRow> _readRow(String id) async {
    final query = _db.select(_db.contacts)..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) {
      throw const FailureException(
        NotFoundFailure('جهة الاتصال غير موجودة.'),
      );
    }
    return row;
  }

  Future<ContactRow?> _readActiveRowOrNull(String id) {
    final query = _db.select(_db.contacts)
      ..where((row) => row.id.equals(id) & row.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  Future<void> _enqueue({
    required ContactRow row,
    required OutboxOperation operation,
  }) async {
    final payload = jsonEncode({
      'id': row.id,
      'name': row.name,
      'kind': row.kind.name,
      'phone': row.phone,
      'note': row.note,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
      'sync_status': row.syncStatus,
      'remote_id': row.remoteId,
    });

    await _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            entity: 'contacts',
            entityId: row.id,
            operation: operation,
            payload: payload,
          ),
        );
  }
}
