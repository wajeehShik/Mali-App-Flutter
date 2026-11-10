import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/outbox_table.dart';
import '../../../core/database/tables/transactions_table.dart'
    as db_transactions;
import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../domain/purchase.dart';
import '../domain/purchase_repository.dart';

/// تنفيذ مستودع المشتريات باستخدام Drift.
/// حفظ العملية وبنودها وسجل outbox يتم داخل المعاملة نفسها.
class PurchaseRepositoryImpl implements PurchaseRepository {
  PurchaseRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Purchase>> watchPurchases({
    DateTime? from,
    DateTime? to,
    String? supplierId,
  }) {
    final start = from ?? DateTime.utc(1900);
    final end = to ?? DateTime.utc(9999, 12, 31, 23, 59, 59);

    return _db.transactionsDao.watchByDateRange(start, end).asyncMap(
      (rows) async {
        final purchases = rows.where((row) {
          return row.type == db_transactions.TransactionType.purchase &&
              (supplierId == null || row.contactId == supplierId);
        });

        return Future.wait(purchases.map(_fromRow));
      },
    );
  }

  @override
  Future<Result<List<Purchase>>> getAll() {
    return guardAsync(() async {
      final rows = await _db.transactionsDao.getAll();
      final purchases = rows.where(
        (row) => row.type == db_transactions.TransactionType.purchase,
      );
      return Future.wait(purchases.map(_fromRow));
    });
  }

  @override
  Future<Result<List<Purchase>>> search(String query) {
    return guardAsync(() async {
      final term = query.trim().toLowerCase();
      final rows = await _db.transactionsDao.getAll();

      final matches = rows.where((row) {
        if (row.type != db_transactions.TransactionType.purchase) {
          return false;
        }
        if (term.isEmpty) return true;

        return row.id.toLowerCase().contains(term) ||
            (row.note?.toLowerCase().contains(term) ?? false);
      });

      return Future.wait(matches.map(_fromRow));
    });
  }

  @override
  Future<Result<Purchase?>> getById(String id) {
    return guardAsync(() async {
      final row = await _db.transactionsDao.getById(id);
      if (row == null ||
          row.type != db_transactions.TransactionType.purchase) {
        return null;
      }
      return _fromRow(row);
    });
  }

  @override
  Future<Result<void>> create(Purchase purchase) {
    final failure = _validate(purchase);
    if (failure != null) return Future.value(Err<void>(failure));

    return guardAsync(() async {
      await _db.transaction(() async {
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: Value(purchase.id),
                type: db_transactions.TransactionType.purchase,
                date: purchase.date.toUtc(),
                accountId: purchase.accountId,
                contactId: Value(purchase.supplierId),
                total: purchase.total.minor,
                paidAmount: purchase.paidAmount.minor,
                note: Value(_cleanOptional(purchase.note)),
              ),
            );

        await _insertItems(purchase);

        final row = await _readRow(purchase.id);
        final itemRows = await _readActiveItemRows(purchase.id);

        await _enqueue(
          row: row,
          items: itemRows,
          operation: OutboxOperation.create,
        );
      });
    });
  }

  @override
  Future<Result<void>> update(Purchase purchase) {
    final failure = _validate(purchase);
    if (failure != null) return Future.value(Err<void>(failure));

    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(purchase.id);

        if (existing == null ||
            existing.type != db_transactions.TransactionType.purchase) {
          throw const FailureException(
            NotFoundFailure('عملية الشراء غير موجودة.'),
          );
        }

        final now = DateTime.now().toUtc();

        await (_db.update(_db.transactions)
              ..where((row) => row.id.equals(purchase.id)))
            .write(
          TransactionsCompanion(
            date: Value(purchase.date.toUtc()),
            accountId: Value(purchase.accountId),
            contactId: Value(purchase.supplierId),
            total: Value(purchase.total.minor),
            paidAmount: Value(purchase.paidAmount.minor),
            note: Value(_cleanOptional(purchase.note)),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        await (_db.update(_db.transactionItems)
              ..where(
                (item) =>
                    item.transactionId.equals(purchase.id) &
                    item.deletedAt.isNull(),
              ))
            .write(
          TransactionItemsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        await _insertItems(purchase);

        final row = await _readRow(purchase.id);
        final itemRows = await _readActiveItemRows(purchase.id);

        await _enqueue(
          row: row,
          items: itemRows,
          operation: OutboxOperation.update,
        );
      });
    });
  }

  @override
  Future<Result<void>> softDelete(String id) {
    return guardAsync(() async {
      await _db.transaction(() async {
        final existing = await _readActiveRowOrNull(id);

        if (existing == null ||
            existing.type != db_transactions.TransactionType.purchase) {
          throw const FailureException(
            NotFoundFailure('عملية الشراء غير موجودة.'),
          );
        }

        final now = DateTime.now().toUtc();

        await (_db.update(_db.transactions)
              ..where((row) => row.id.equals(id)))
            .write(
          TransactionsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        await (_db.update(_db.transactionItems)
              ..where(
                (item) =>
                    item.transactionId.equals(id) & item.deletedAt.isNull(),
              ))
            .write(
          TransactionItemsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );

        final row = await _readRow(id);
        final itemRows = await _readAllItemRows(id);

        await _enqueue(
          row: row,
          items: itemRows,
          operation: OutboxOperation.delete,
        );
      });
    });
  }

  Failure? _validate(Purchase purchase) {
    final errors = <String, String>{};

    if (purchase.id.trim().isEmpty) {
      errors['id'] = 'معرّف عملية الشراء مطلوب.';
    }

    if (purchase.accountId.trim().isEmpty) {
      errors['accountId'] = 'الحساب مطلوب.';
    }

    if (purchase.supplierId != null && purchase.supplierId!.trim().isEmpty) {
      errors['supplierId'] = 'المورد المحدد غير صالح.';
    }

    if (purchase.items.isEmpty) {
      errors['items'] = 'أضف بندًا واحدًا على الأقل.';
    }

    for (final item in purchase.items) {
      if (item.productId.trim().isEmpty) {
        errors['productId'] = 'المنتج مطلوب لكل بند.';
      }
      if (item.quantityMilli <= 0) {
        errors['quantity'] = 'كمية كل بند يجب أن تكون أكبر من صفر.';
      }
      if (item.unitPrice.minor < 0 || item.unitCost.minor < 0) {
        errors['unitPrice'] = 'سعر وتكلفة الوحدة لا يمكن أن يكونا سالبين.';
      }
    }

    if (purchase.total.minor <= 0) {
      errors['total'] = 'إجمالي الشراء يجب أن يكون أكبر من صفر.';
    }

    if (purchase.paidAmount.minor < 0) {
      errors['paidAmount'] = 'المبلغ المدفوع لا يمكن أن يكون سالبًا.';
    } else if (purchase.paidAmount.minor > purchase.total.minor) {
      errors['paidAmount'] = 'المبلغ المدفوع لا يمكن أن يتجاوز إجمالي الشراء.';
    }

    final calculatedTotal = purchase.items.fold<int>(
      0,
      (sum, item) => sum + item.lineTotal.minor,
    );

    if (purchase.items.isNotEmpty &&
        calculatedTotal != purchase.total.minor) {
      errors['total'] = 'إجمالي العملية لا يساوي مجموع إجماليات البنود.';
    }

    if ((purchase.note?.trim().length ?? 0) > 500) {
      errors['note'] = 'الملاحظة طويلة جدًا.';
    }

    if (errors.isEmpty) return null;

    return ValidationFailure(
      'تحقق من بيانات عملية الشراء.',
      fieldErrors: errors,
    );
  }

  Future<void> _insertItems(Purchase purchase) async {
    for (final item in purchase.items) {
      await _db.into(_db.transactionItems).insert(
            TransactionItemsCompanion.insert(
              transactionId: purchase.id,
              productId: item.productId,
              quantity: item.quantityMilli,
              unitPrice: item.unitPrice.minor,
              unitCost: Value(item.unitCost.minor),
            ),
          );
    }
  }

  Future<Purchase> _fromRow(TransactionRow row) async {
    final itemRows = await _readActiveItemRows(row.id);

    return Purchase(
      id: row.id,
      date: row.date,
      accountId: row.accountId,
      supplierId: row.contactId,
      total: Money(row.total),
      paidAmount: Money(row.paidAmount),
      note: row.note,
      items: itemRows
          .map(
            (item) => PurchaseItem(
              productId: item.productId,
              quantityMilli: item.quantity,
              unitPrice: Money(item.unitPrice),
              unitCost: Money(item.unitCost),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<TransactionRow> _readRow(String id) async {
    final query = _db.select(_db.transactions)
      ..where((row) => row.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) {
      throw const FailureException(
        NotFoundFailure('عملية الشراء غير موجودة.'),
      );
    }
    return row;
  }

  Future<TransactionRow?> _readActiveRowOrNull(String id) {
    final query = _db.select(_db.transactions)
      ..where((row) => row.id.equals(id) & row.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  Future<List<TransactionItemRow>> _readActiveItemRows(
    String transactionId,
  ) {
    final query = _db.select(_db.transactionItems)
      ..where(
        (item) =>
            item.transactionId.equals(transactionId) &
            item.deletedAt.isNull(),
      )
      ..orderBy([(item) => OrderingTerm.asc(item.createdAt)]);
    return query.get();
  }

  Future<List<TransactionItemRow>> _readAllItemRows(
    String transactionId,
  ) {
    final query = _db.select(_db.transactionItems)
      ..where((item) => item.transactionId.equals(transactionId))
      ..orderBy([(item) => OrderingTerm.asc(item.createdAt)]);
    return query.get();
  }

  String? _cleanOptional(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  Future<void> _enqueue({
    required TransactionRow row,
    required List<TransactionItemRow> items,
    required OutboxOperation operation,
  }) async {
    final payload = jsonEncode({
      'id': row.id,
      'type': row.type.name,
      'date': row.date.toUtc().toIso8601String(),
      'account_id': row.accountId,
      'to_account_id': row.toAccountId,
      'contact_id': row.contactId,
      'category_id': row.categoryId,
      'total': row.total,
      'paid_amount': row.paidAmount,
      'note': row.note,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
      'sync_status': row.syncStatus,
      'remote_id': row.remoteId,
      'items': items
          .map(
            (item) => {
              'id': item.id,
              'product_id': item.productId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'unit_cost': item.unitCost,
              'created_at': item.createdAt.toUtc().toIso8601String(),
              'updated_at': item.updatedAt.toUtc().toIso8601String(),
              'deleted_at': item.deletedAt?.toUtc().toIso8601String(),
              'sync_status': item.syncStatus,
              'remote_id': item.remoteId,
            },
          )
          .toList(growable: false),
    });

    await _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            entity: 'transactions',
            entityId: row.id,
            operation: operation,
            payload: payload,
          ),
        );
  }
}
